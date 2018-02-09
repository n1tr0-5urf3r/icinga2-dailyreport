#!/bin/bash
#-------------------------------#
#    Last change: 09.02.2018    #
# icinga2 daily report delivery #
#-------------------------------#


# Global variables
tmpdir=/tmp
reportfile=$tmpdir/icinga2_dailyreport.txt
date=$(date)
hostfound=0
completefile=$tmpdir/icinga2_status.txt
finalresult=$tmpdir/icinga2_finalresult.txt
service=placeholder

# Get line where error occured in complete file
# Search upwards until UP or DOWN comes up
# echo Host with UP/DOWN + service name into final result file
# proceed to next error
getHost(){
sed -i 's/://g' $reportfile
        cat $reportfile | while read line status; do
                hostfound=0
                service=$(head -n $line $completefile | tail -n 1)
                while [ $hostfound -eq 0 ]; do
                        result=$(head -n $line $completefile | tail -n 1)
                        if [[ $result = *"UP "* ]] || [[ $result = *"DOWN "* ]]
                                then
                                hostfound=1
                                echo -e "$result\r" >> $finalresult
                                echo $service >> $finalresult
                                echo -e "\n" >> $finalresult
                        fi
                        line=$((line-1))
                done
        done
echo -e "\n" >> $finalresult
}

checkIfEmpty(){
# Checks if reportfile is empty
# Crawls for host if not
nocrit=$([ -s $reportfile ];echo $?)
if [ "$nocrit" -eq 0 ]
	then
	        getHost
	else
	        echo -e "Keine $1 \n\n" >> $finalresult
fi
rm -f $reportfile
}

# Create empty reportfile
touch $reportfile
echo "Täglicher Bericht icinga2 $date" > $finalresult
echo -e "\n" >> $finalresult
/usr/bin/icingacli monitoring list services >> $completefile

# Collect data
echo "Critical:" >> $finalresult
/usr/bin/icingacli monitoring list services | grep -n 'CRIT ' > $reportfile
checkIfEmpty "kritischen Fehler!"

echo "Warning:" >> $finalresult
/usr/bin/icingacli monitoring list services | grep -n 'WARN ' > $reportfile
checkIfEmpty "Warnungen!"

echo "Unknown:" >> $finalresult
/usr/bin/icingacli monitoring list services | grep -n 'UNKN ' > $reportfile
checkIfEmpty "unbekannten Fehler!"

# Formatting
sed -i 's/   UP /UP /g' $finalresult
sed -i 's/   DOWN /DOWN /g' $finalresult
sed -i 's/CRIT /   CRIT /g' $finalresult
sed -i 's/UNKN /   UNKN /g' $finalresult
sed -i 's/WARN /   WARN /g' $finalresult

# Send mails 
	cat $finalresult  | /usr/bin/mutt -e 'my_hdr From: icinga2@example' -s "Icinga2 daily report" recipient@example.com

# Remove temporary files
rm $completefile
rm $finalresult
