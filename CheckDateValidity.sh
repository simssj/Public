#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
# Validate a given date/time in Bash on either Linux or Mac (OSX).

# Expected date/time format (in quotes from the command line):  YYYY-MM-DD HH:MM:SS
# Example(s):  ./this_script "2012-02-29 13:00:00"   # IS valid
#              ./this_script "2013-02-29 13:00:00"   # Is NOT valid

START_DATETIME=$1

function report_error_and_exit
{
   local MSG=$1
   echo "$MSG" >&2
#   exit 1
}

# We can use OSTYPE to determine what OS we're running on.
# From http://stackoverflow.com/questions/394230/detect-the-os-from-a-bash-script

# Determine whether the given START_DATETIME is valid.
if [[ "$OSTYPE" == "linux-gnu" ]]
then
   # Validate the date on a Linux machine (Redhat or Debian).  On Linux, this is 
   # as easy as adding one minute and checking the return code.  If one minute 
   # cannot be added, then the starting value is not a valid date/time.
   date -d "$START_DATETIME UTC + 1 min" +"%F %T" &> /dev/null
   test $? -eq 0 || report_error_and_exit "'$START_DATETIME' is not a valid date/time value. $OSTYPE"
elif [[ "$OSTYPE" == "darwin"* ]]
then
   # Validate the date on a Mac (OSX).  This is done by adding and subtracting
   # one minute from the given date/time.  If the resulting date/time string is identical 
   # to the given date/time string, then the given date/time is valid.  If not, then the
   # given date/time is invalid.
   TEST_DATETIME=$(date -v+1M -v-1M -jf "%F %T" "$START_DATETIME" +"%F %T" 2> /dev/null)

   if [[ "$TEST_DATETIME" != "$START_DATETIME" ]]
   then
      report_error_and_exit "'$START_DATETIME' is not a valid date/time value. $OSTYPE"
   fi
fi

echo "The date/time is valid."
#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
