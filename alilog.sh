#!/bin/sh
file=./getlogs.json
out=/tmp/ali.log
myip=/tmp/ip.txt
waf=./waf_black.txt
ip_diff=/tmp/ip_diff.txt
ip_end=/tmp/ip_end.txt
ip_other=/tmp/ip_other.txt

getlog(){
Tt=`date +%s`
Ft=`expr ${Tt} - 86400`
echo ${Tt} ${Ft}
sed -i /Time/d ${file}
sed -i '4a\"toTime": "'${Tt}'",\n"fromTime": "'${Ft}'",' ${file}
aliyunlog log get_logs --request="file://${file}" --format-output=json,no_escape >${out}
}

format(){
cat $out |sed '/source/d'|sed '/time/d'|sed -n '{N;s/\n/\t/p}'|sed '/\}/d'|sed '/\[/d'|sed 's/"//g'|awk -F '[,| ]'  '{print $6,$(NF-1)}'|awk '{if($2>=100)print $1}' >${myip}
#echo ${myip}
#cat ${myip}
}

diff(){
  sort ${myip} ${waf} |uniq -d > ${ip_diff}
  sort ${myip} ${ip_diff} |uniq -d  >${ip_end}
  sort ${myip} ${ip_end} |uniq -u  >${ip_other}
  if [ -s ${ip_end} ];then
    echo "critical 以下攻击ip在黑名单中"
    cat ${ip_end}
    echo "info 以下攻击ip不在黑名单中"
    cat ${ip_other}
  else
    echo "info all攻击ip不在黑名单中"
    cat ${myip}
  fi
}

#执行阶段
#format
if [ -s ${myip} ];then
  diff
else
  echo "本时段无符合要求的ip"
fi
exit 0
