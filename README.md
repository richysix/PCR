# PCR

PCR primer design using Primer3

## Modules

Contains the following modules:

*   Primer.pm       - object representing a single PCR primer
*   PrimerPair.pm   - object representing two primers designed to amplify a specific region
*   Primer3.pm      - Module to run Primer3
*   PrimerDesign.pm - Module to design and select pairs of primers for given targets

## Primer3

The primer design modules require [Primer3](http://primer3.sourceforge.net/) to be installed.
The easiest way for the PCR modules to detect this is to have primer_core and
primer3_config present in your path.
The other option is to specify the paths by setting the environment variables
PRIMER3_BIN and PRIMER3_CONFIG.  
For example on bash  

    export PRIMER3_BIN=/Users/user1/bin/primer3_core
    export PRIMER3_CONFIG=/Users/user1/bin/primer3_config

## Installation

Install [Primer3](http://primer3.sourceforge.net/) first.
Download latest [PCR](https://github.com/richysix/PCR/releases) release and
install using make.

e.g.  

    cd ~/src
    wget https://github.com/richysix/PCR/releases/download/v0.2.2/PCR-0.2.2.tar.gz
    tar -xvzf PCR-0.2.2.tar.gz
    cd PCR-0.2.2
    perl Makefile.PL
    make
    make test
    make install



Copyright and License information for Primer3 can be found [here](http://primer3.sourceforge.net/primer3_manual.htm#copyrightLicense).
