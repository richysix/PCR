PCR
===

PCR primer design using Primer3

Modules
-------

Contains the following modules:

*   Primer.pm       - object representing a single PCR primer
*   PrimerPair.pm   - object representing two primers designed to amplify a specific region
*   Primer3.pm      - Module to run Primer3
*   PrimerDesign.pm - Module to design and select pairs of primers for given targets

Primer3
-------

The primer design modules require [Primer3](http://primer3.sourceforge.net/) to be installed.
The easiest way to do this is to have primer_core and primer3_config present in your path.
The other option is to specify the paths in thePrimer3 config file.

Copyright and License information for Primer3 can be found [here](http://primer3.sourceforge.net/primer3_manual.htm#copyrightLicense).

