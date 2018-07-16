#! /usr/bin/env tcsh
#=======================================================================
#+
# NAME:
#   beavis-ci.csh
#
# PURPOSE:
#   Enable occasional integration and testing. Like travis-ci but dumber.
#
# COMMENTS:
#   Makes "rendered" notebooks and deploys them to a "rendered" orphan 
#   branch, pushed to GitHub for web display. 
#
# INPUTS:
#
# OPTIONAL INPUTS:
#   -h --help     Print this header
#   -u --username GITHUB_USERNAME, defaults to the environment variable
#   -k --key      GITHUB_API_KEY, defaults to the environment variable
#   -n --no-push  Only run the notebooks, don't deploy the outputs
#   --html        Make html outputs instead
#
# OUTPUTS:
#
# EXAMPLES:
#
#   ./beavis-ci.csh -u drphilmarshall -k a0573fc078b7e8f5c10660e1f29e58678bf4d118
#
#-
# ======================================================================

set help = 0
set just_testing = 0
set html = 0

while ( $#argv > 0 )
    switch ($argv[1])
    case -h:
        shift argv
        set help = 1
        breaksw
    case --{help}:
        shift argv
        set help = 1
        breaksw
    case -n:
        shift argv
        set just_testing = 1
        breaksw
    case --{no-push}:
        shift argv
        set just_testing = 1
        breaksw
    case -u:
        shift argv
        set GITHUB_USERNAME = $argv[1]
        shift argv
        breaksw
    case --{username}:
        shift argv
        set GITHUB_USERNAME = $argv[1]
        shift argv
        breaksw   
    case -k:
        shift argv
        set GITHUB_API_KEY = $argv[1]
        shift argv
        breaksw
    case --{key}:
        shift argv
        set GITHUB_API_KEY = $argv[1]
        shift argv
        breaksw 
    case --{html}:
        shift argv
        set html = 1
        breaksw  
    endsw
end

if ($help) then
  more $0
  goto FINISH
endif

echo "Welcome to beavis-ci: manual occasional integration"
echo "Cloning the DC2_Repo into the .beavis workspace:"

# Check out a fresh clone in a temporary hidden folder, over-writing 
# any previous edition:
\rm -rf .beavis ; mkdir .beavis ; cd .beavis
git clone git@github.com:LSSTDESC/DC2_Repo.git
cd DC2_Repo/Notebooks

if ($html) then
    echo "Making static HTML pages from the available notebooks:"
    set outputformat = "HTML"
    set ext = "html"
    set branch = "html"
else
    echo "Rendering the available notebooks:"
    set outputformat = "notebook"
    set ext = "nbconvert.ipynb"
    set branch = "rendered" 
endif
ls -l *.ipynb

set outputs = ()
foreach notebook ( *.ipynb )
    # Rename files to make them easier to work with:
    set ipynbfile = `echo "$notebook" | sed s/' '/'_'/g`
    mv "$notebook" $ipynbfile
    set logfile = $cwd/$ipynbfile:r.log
    jupyter nbconvert --ExecutePreprocessor.kernel_name=desc-stack \
                      --ExecutePreprocessor.timeout=600 --to HTML \
                      --execute $ipynbfile >& $logfile
    set output = $ipynbfile:r.$ext
    if ( -e $output ) then
        set outputs = ( $outputs $output )
        echo "SUCCESS: $output produced."
    else
        echo "WARNING: $output was not created, read the log in $logfile for details."
    endif
end

if $just_testing goto CLEANUP
# Otherwise:

echo "Attempting to push the rendered outputs to GitHub in an orphan branch..."
# Check for GitHub credentials and then push the pages up:
if ( $?GITHUB_USERNAME && $?GITHUB_API_KEY ) then

    echo "...with key $GITHUB_API_KEY and username $GITHUB_USERNAME"

    echo -n "If this looks OK, hit any key to continue..."
    set goforit = $<

    cd ../
    git branch -D $branch >& /dev/null
    git checkout --orphan $branch
    git rm -rf .
    cd Notebooks
    git add -f $outputss
    git commit -m "pushed rendered notebooks"
    git push -q -f \
        https://${GITHUB_USERNAME}:${GITHUB_API_KEY}@github.com/LSSTDESC/DC2_Repo  $branch
    echo "Done!"
    git checkout $branch

    echo ""
    echo "Please read the above output very carefully to see that things are OK. To check we've come back to the dev branch correctly, here's a git status:"
    echo ""

    git status

else
    echo "...No GITHUB_API_KEY and/or GITHUB_USERNAME set, giving up."
endif


CLEANUP:
cd ../../
# \rm -rf .beavis
# Uncomment the above when script works!

# ======================================================================
FINISH:
# ======================================================================
