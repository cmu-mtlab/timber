set -eou pipefail

TIMBER=$(readlink -f $(dirname $0))
cd $TIMBER

# Remove existing files
rm -rf grascore
rm -rf grex
rm -rf ducttape
rm -rf multeval
rm -rf cdec
rm -rf parallel-20130122
rm -f parallel-20130122.tar.bz2

# Check out all necessary dependencies
git clone git://github.com/ghanneman/grascore.git
git clone git://github.com/ghanneman/grex.git
wget http://www.cs.cmu.edu/~jhclark/downloads/ducttape-0.3.tgz
git clone git://github.com/jhclark/multeval.git
git clone git://github.com/redpony/cdec.git
wget http://ftp.gnu.org/gnu/parallel/parallel-20130122.tar.bz2

mkdir -p prefix
mkdir -p prefix/bin

# Build dependencies
# grascore
cd $TIMBER
# grex
cd grex
mkdir bin
ant
cd $TIMBER
# ducttape
tar xzvf ducttape-0.3.tgz
rm ducttape-0.3.tgz
cd $TIMBER
# multeval
cd multeval
bash ./get_deps.sh
ant
cd $TIMBER
# cdec
cd cdec
autoreconf -ifv
./configure
make
cd $TIMBER/prefix/bin
ln -s ../../cdec/decoder/cdec .
cd $TIMBER
# parallel
tar xjvf parallel-20130122.tar.bz2
rm parallel-20130122.tar.bz2
cd parallel-20130122
./configure --prefix=$TIMBER/prefix && make && make install
cd $TIMBER

echo "Please be sure to add ducttape to your PATH variable, if you haven't already."
echo "This can be achieved with the following command:"
echo "export PATH=$TIMBER/ducttape-0.3:\$PATH"
echo
echo "You should also add timber's bin directory to your path like this:"
echo "export PATH=$TIMBER/prefix/bin:\$PATH"
echo
echo "You should also consider adding these path exports to your ~/.bashrc (or similar) file so they are available after logging out."
echo
echo "You can run a sample system by first updating the lines"
echo "timberRoot=\"/home/armatthe/git/timber\""
echo "and"
echo "scriptDir=\"/home/armatthe/git/timber/timber_scripts\""
echo "to point to $TIMBER and $TIMBER/timber_scripts respectively in sample.tconf."
echo "Then simply run the command:"
echo "./timber.tape -C sample.tconf -p Full"
echo "Done!"
