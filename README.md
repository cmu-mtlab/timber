timber
======

Tool to build syntax-based machine translation systems

Installing Boost
================
Ensure that $PREFIX/include is in $INCLUDE_PATH and
$PREFIX/lib is in $LD_LIBRARY_PATH

export BOOST_ROOT=some-directory/boost_x_y_z
export LDFLAGS=-L$BOOST_ROOT/stage/lib
export CPPFLAGS=-I$BOOST_ROOT

For some reason, newer versions of Boost seem to give an error related to the thread library.
Reverting to 1.51 seems to work.

When compiling cdec, you may need to add $BOOST_ROOT/stage/libs to your $LIBRARY_PATH (n.b.: not LD_LIBRARY_PATH).
When installing the cdec python module, try running python setup.py install --home=~.

Dependencies
============
default-jdk
ant
Boost (to build cdec)
curl (to download multeval dependencies)
flex (to build cdec)
pv (used in timber_scripts)
libtool (for autoreconf)
autoconf (to build cdec and multeval)
Python >= 2.7
