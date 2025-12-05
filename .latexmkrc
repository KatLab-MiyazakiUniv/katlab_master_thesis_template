$latex = 'uplatex %O %S';
$bibtex = 'pbibtex %O %B';
$dvipdf = 'dvipdfmx %O -o %D %S';
$pdf_mode = 3;

# Output directory configuration
$out_dir = 'build';
$aux_dir = 'build';

# Ensure output directories exist
system("mkdir -p build");
