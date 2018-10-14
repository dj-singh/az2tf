prefixa=`echo $0 | awk -F 'azurerm_' '{print $2}' | awk -F '.sh' '{print $1}' `
tfp=`printf "azurerm_%s" $prefixa`
if [ "$1" != "" ]; then
    rgsource=$1
else
    echo -n "Enter name of Resource Group [$rgsource] > "
    read response
    if [ -n "$response" ]; then
        rgsource=$response
    fi
fi
azr=`az network traffic-manager profile list -g $rgsource`
count=`echo $azr | jq '. | length'`
if [ "$count" -gt "0" ]; then
    count=`expr $count - 1`
    for i in `seq 0 $count`; do
        pname=`echo $azr | jq ".[(${i})].name" | tr -d '"'`
        azr2=`az network traffic-manager endpoint list -g $rgsource --profile-name $pname`
        icount=`echo $azr2 | jq '. | length'`
        if [ "$icount" -gt "0" ]; then
            icount=`expr $icount - 1`
            for j in `seq 0 $icount`; do
                name=`echo $azr2 | jq ".[(${j})].name" | tr -d '"'`
                rg=`echo $azr2 | jq ".[(${j})].resourceGroup" | tr -d '"'`
                id=`echo $azr2 | jq ".[(${j})].id" | tr -d '"'`
                type=`echo $azr2 | jq ".[(${j})].type" | cut -d'/' -f3 | tr -d '"'`
                pri=`echo $azr2 | jq ".[(${j})].priority" | tr -d '"'`
                wt=`echo $azr2 | jq ".[(${j})].weight" | tr -d '"'`
                tgt=`echo $azr2 | jq ".[(${j})].target" | tr -d '"'`
                eps=`echo $azr2 | jq ".[(${j})].endpointStatus" | tr -d '"'`

                prefix=`printf "%s.%s" $prefixa $rg`
                outfile=`printf "%s.%s__%s.tf" $tfp $rg $name`
                echo $az2tfmess > $outfile
                
                printf "resource \"%s\" \"%s__%s\" {\n" $tfp $rg $name >> $outfile
                printf "\t name = \"%s\"\n" $name >> $outfile
                printf "\t resource_group_name = \"%s\"\n" $rg >> $outfile
                printf "\t profile_name = \"%s\"\n" $pname >> $outfile
                printf "\t type = \"%s\"\n" $type >> $outfile
                printf "\t priority = \"%s\"\n" $pri >> $outfile
                printf "\t weight = \"%s\"\n" $wt >> $outfile
                printf "\t target = \"%s\"\n" $tgt >> $outfile
                printf "\t endpoint_status = \"%s\"\n" $eps >> $outfile          
          
                #
                # New Tags block
                tags=`echo $azr | jq ".[(${i})].tags"`
                tt=`echo $tags | jq .`
                tcount=`echo $tags | jq '. | length'`
                if [ "$tcount" -gt "0" ]; then
                    printf "\t tags { \n" >> $outfile
                    tt=`echo $tags | jq .`
                    keys=`echo $tags | jq 'keys'`
                    tcount=`expr $tcount - 1`
                    for j in `seq 0 $tcount`; do
                        k1=`echo $keys | jq ".[(${j})]"`
                        tval=`echo $tt | jq .$k1`
                        tkey=`echo $k1 | tr -d '"'`
                        printf "\t\t%s = %s \n" $tkey "$tval" >> $outfile
                    done
                    printf "\t}\n" >> $outfile
                fi
                
                
                printf "}\n" >> $outfile
                #
                echo $prefix
                echo $prefix__$name
                cat $outfile
                statecomm=`printf "terraform state rm %s.%s__%s" $tfp $rg $name`
                echo $statecomm >> tf-staterm.sh
                eval $statecomm
                evalcomm=`printf "terraform import %s.%s__%s %s" $tfp $rg $name $id`
                echo $evalcomm >> tf-stateimp.sh
                eval $evalcomm
                
            done
        fi      
    done
fi
