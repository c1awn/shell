#!/bin/sh
#说明：本脚本通过aliyunlog cli执行SQL得到初始结果，包含ip、pv等，再对比ip和黑名单ip
cat getlogs.json 样例
# {
# "topic": "slb_layer7_access_log",
# "logstore": "slb",
# "project": "sample",
# "toTime": "1651840420",
# "fromTime": "1651840400",
# "offset": "0",
# "query": "* select status,COUNT(*) as pv group by status order by pv desc limit 3",
# "line": "2",
# "reverse": "true"
# }

# cat /tmp/ali.log 样例
# [
  # {
    # "__source__": "",
    # "__time__": "1651840532",
    # "client_ip": "192.168.1.100",
    # "pv": "3006",
    # "time": "2022-05-07"
  # },
  # {
    # "__source__": "",
    # "__time__": "1651840532",
    # "client_ip": "192.168.1.101",
    # "pv": "2",
    # "time": "2022-05-07"
  # }
# ]



file=./getlogs.json
out=/tmp/ali.log
myip=/tmp/ip.txt
waf=./waf_black.txt
ip_diff=/tmp/ip_diff.txt
ip_end=/tmp/ip_end.txt
ip_other=/tmp/ip_other.txt

getlogs(){
Tt=`date +%s`
#获取一天前的时间戳86400s
Ft=`expr ${Tt} - 86400`
echo ${Tt} ${Ft}
#替换JSON文本的时间戳
sed -i /Time/d ${file}
sed -i '4a\"toTime": "'${Tt}'",\n"fromTime": "'${Ft}'",' ${file}
#执行SQL，此为最核心的命令，如果报错，说明SQL语法有问题，或者需要转义（会提示Python 方法、模块error）
aliyunlog log get_logs --request="file://${file}" --format-output=json,no_escape >${out}
}

format(){
#得到ip字段，sed -n '{N;s/\n/\t/p}'合并行，筛选pv大于100的
cat $out |sed '/source/d'|sed '/time/d'|sed -n '{N;s/\n/\t/p}'|sed '/\}/d'|sed '/\[/d'|sed 's/"//g'|awk -F '[,| ]'  '{print $6,$(NF-1)}'|awk '{if($2>=100)print $1}' >${myip}
#echo ${myip}
#cat ${myip}
}

diff(){
  #取交集
  sort ${myip} ${waf} |uniq -d > ${ip_diff}
  #取交集，得到在黑名单的ip
  sort ${myip} ${ip_diff} |uniq -d  >${ip_end}
  #取差集，得到不在黑名单的ip
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
getlogs
format
if [ -s ${myip} ];then
  diff
else
  echo "本时段无符合要求的ip"
fi
exit 0
