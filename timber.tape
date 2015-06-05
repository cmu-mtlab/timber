#!/usr/bin/env ducttape

task GrammarExtraction < sourceTrees=$sourceTrees targetTrees=$targetTrees alignment=$alignment > rules aligns :: numCores=@ timberRoot=@ scriptDir=@ {
   # TODO: Parallelize
   bash $scriptDir/grammarExtraction.sh $numCores $sourceTrees $targetTrees $alignment 5 5 true false false 2 $aligns > $rules
}

task LexicalProbs < source=$source target=$target alignment=$alignment > e2f f2e :: timberRoot=@ scriptDir=@ {
   echo "PWD: $PWD"
   echo "Script dir: " $(readlink -f $scriptDir)
   perl $scriptDir/lex.perl --f $source --e $target --a $alignment --f2e $f2e --e2f $e2f
}

task GrammarScore < rules=$rules@GrammarExtraction e2f=$e2f@LexicalProbs f2e=$f2e@LexicalProbs sourceLCTable=/dev/null targetLCTable=/dev/null > scoredGrammar glueGrammar scoreNames :: numCores=@ timberRoot=@ scriptDir=@ { 
   python $scriptDir/genScoringScript.py --lexE2F $e2f --lexF2E $f2e --glueGrammar $glueGrammar --numCores $numCores --srcLCTable $sourceLCTable --tgtLCTable $targetLCTable $rules $scoredGrammar $scoreNames > scoringScript.sh
   bash scoringScript.sh  
}

task FilterToTestSet < fullGrammar=$scoredGrammar@GrammarScore trainTargetTrees=$targetTrees source=(TuneOrTest: tune=$tuneSetSource test=$testSetSource) scoreNames=$scoreNames@GrammarScore > filteredGrammarsDir :: numCores=@ timberRoot=@ scriptDir=@ { 
   cp $scoreNames ./scoreNames
   bash $scriptDir/filtering.sh $fullGrammar $source $trainTargetTrees ./scoreNames $numCores $filteredGrammarsDir 1.01
}

task MakeCdecIni < languageModel=$languageModel glueGrammar=$glueGrammar@GrammarScore > cdecIni {
    echo "formalism=scfg" > $cdecIni
    echo "scfg_no_hiero_glue_grammar=true" >> $cdecIni
    echo "feature_function=KLanguageModel -n N4LM $languageModel" >> $cdecIni
    echo "scfg_extra_glue_grammar=$glueGrammar" >> $cdecIni
    echo "feature_function=WordPenalty" >> $cdecIni
    echo "add_pass_through_rules=true" >> $cdecIni
    echo "density_prune=100" >> $cdecIni
}

task Tune < filteredGrammarsDir=$filteredGrammarsDir@FilterToTestSet[TuneOrTest:tune] tuneSource=$tuneSetSource tuneRefs=$tuneSetRefs cdecIni=$cdecIni@MakeCdecIni > optimizedWeights :: numCores=@ timberRoot=@ scriptDir=@ {
    initialWeights="initialWeights.txt"
    wrappedSource="wrappedSource.txt"
    workDir="./mert-work"

    echo "WordPenalty -0.38"  > $initialWeights
    echo "PassThrough -0.06" >> $initialWeights
    echo "N4LM 1.12"         >> $initialWeights
    echo "N4LM_OOV -1.12"    >> $initialWeights
    echo "rarity 0.07"       >> $initialWeights
    echo "phrase-SGT -1.81"  >> $initialWeights
    echo "phrase-TGS -2.91"  >> $initialWeights
    echo "lhsGrhs -1.21"     >> $initialWeights
    echo "lexical-SGT -0.52" >> $initialWeights
    echo "lexical-TGS -0.94" >> $initialWeights
    echo "abstract? 0.56"    >> $initialWeights
    echo "lexical? 1.79"     >> $initialWeights
    echo "glue? -1.25"       >> $initialWeights

    paste -d $'\t' $tuneSource $tuneRefs | sed 's/\t/\|\|\|/g' > ./DevSet
    cat ./DevSet | python $scriptDir/wrapCorpus.py $filteredGrammarsDir > wrappedDevSet
    perl $timberRoot/cdec/training/dpmert/dpmert.pl --devset ./wrappedDevSet --weights $initialWeights --jobs $numCores --output-dir $workDir --config $cdecIni

    bestWeights=$(ls -1 $workDir/weights.* | sort -n | tail -n 1)
    mv $bestWeights $optimizedWeights
}

task Decode < testSource=$testSetSource filteredGrammarsDir=$filteredGrammarsDir@FilterToTestSet[TuneOrTest:test] cdecIni=$cdecIni@MakeCdecIni optimizedWeights=$optimizedWeights@Tune > output :: numCores=@ timberRoot=@ scriptDir=@ {
   wrappedSource="wrappedSource.txt" 
   cat $testSource | python $scriptDir/wrapCorpus.py $filteredGrammarsDir > $wrappedSource
   bash $scriptDir/decode.sh $wrappedSource $cdecIni $optimizedWeights $numCores > $output
}

task Evaluate < output=$output@Decode refs=$testSetRefs > bleu meteor ter length :: timberRoot=@ {
   METEORTASK=li
   METEORLANG=other
   scoreFile=scores.txt
   ln -s $timberRoot/multeval/constants .
   $timberRoot/multeval/multeval.sh eval --refs $refs --hyps-baseline $output --meteor.task $METEORTASK --meteor.language $METEORLANG &> $scoreFile
   tail -n 2 $scoreFile | head -n 1 | sed 's/(\S\+)//g' | sed 's/\s\+/\t/g' | cut -f 2 > $bleu
   tail -n 2 $scoreFile | head -n 1 | sed 's/(\S\+)//g' | sed 's/\s\+/\t/g' | cut -f 3 > $meteor
   tail -n 2 $scoreFile | head -n 1 | sed 's/(\S\+)//g' | sed 's/\s\+/\t/g' | cut -f 4 > $ter
   tail -n 2 $scoreFile | head -n 1 | sed 's/(\S\+)//g' | sed 's/\s\+/\t/g' | cut -f 5 > $length
}

summary EvaluationSummary {
   of Evaluate > Score {
      cp $bleu $Score
   }
}

plan Full {
   reach Evaluate
}
