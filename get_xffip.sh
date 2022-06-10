#!/bin/sh
#主业务流向是 client->CDN->WAF->SLB->nginx，部分业务流向是 client->WAF->SLB->nginx
#根据nginx日志XFF字段判断：如果XFF ip大于等于3，取XFF倒数第二个ip和CDN回源ip对比
dir=/home/work
last_minutes=10
logfile=/var/log/nginx/access.log
host=www.ex.com
xff_tail2_ip=/tmp/xff_tail2_ip.txt
xff_tail2_ip_tmp=/tmp/xff_tail2_ip_tmp.txt
xff_tail2_ip_tmp2=/tmp/xff_tail2_ip_tmp2.txt
cdn_back_ip=cdn_back_ip.txt
cdn_back_ip_deal=cdn_back_ip_deal.txt
cdn_diff=/tmp/cdn_diff.txt
warn_ip_tmp=/tmp/warn_ip_tmp.txt
warn_ip=/tmp/warn_ip.txt
send_txt=/tmp/xff_warn.txt



echo $host
#开始时间
start_time=`date -d "$last_minutes minutes ago" +"%H:%M:%S"`
echo $start_time
#结束时间
stop_time=`date +"%H:%M:%S"`
echo $stop_time

#如果XFF ip大于等于3，获取XFF倒数第二个ip
get_xff(){
  tac /var/log/nginx/access.log|awk '{if($6~/'"$host"'/)print $0}'|awk -v st="$start_time" -v et="$stop_time" '{t=substr($4,RSTART+14,21);if(t>=st && t<=et) {print $0}}'|awk -F '"' '{print $(NF-1)}'|sed 's/ //g'|awk -F, '{if(NF>=3)print $(NF-1)}'|sort|uniq -c|sort -nr|awk '{print $2,$1}'  >${xff_tail2_ip}
  tac /var/log/nginx/access.log|awk '{if($6~/'"$host"'/)print $0}'|awk -v st="$start_time" -v et="$stop_time" '{t=substr($4,RSTART+14,21);if(t>=st && t<=et) {print $0}}'|awk -F '"' '{print $(NF-1)}'|sed 's/ //g'|awk -F, '{if(NF>=3)print $(NF-1)}'|awk -F. 'BEGIN { OFS="." }{NF-=1}1'|sort|uniq  >${xff_tail2_ip_tmp}
  awk -F. '{print $1"."$2"."$3","$4}' ${xff_tail2_ip} >${xff_tail2_ip_tmp2}
}  

#比较XFF倒数第二个ip和cdn回源网段
diff(){
   awk 'NR==FNR{a[$1]=$0;next}!($1 in a){print}' ${cdn_back_ip_deal} ${xff_tail2_ip_tmp}  >${cdn_diff}
}

#反取ip
back_fecth(){
  awk -F, 'NR==FNR{a[$1]=$0;next}($1 in a){print}' ${cdn_diff} ${xff_tail2_ip_tmp2}|sed 's/,/./g' >${warn_ip_tmp}
  awk -F, 'NR==FNR{a[$1]=$0;next}($1 in a){print}' ${warn_ip_tmp} ${xff_tail2_ip} >${warn_ip}
  cat ${warn_ip}|tr "\n" ','|sed 's/,/\\n/g' >${send_txt}
  sed -i 's/ /\\u0020/g' ${send_txt}
}

dd_send(){
  content=`cat ${send_txt}`
  t=`date +%Y-%m-%d_%H:%M:%S`
  curl 'http://XXX/ddapi/robot/send?access_token=XX' \
     -H 'Content-Type: application/json' \
     -d '
    {"msgtype": "text", 
     "isAtAll": true,
      "text": {
        "content": "【XFF伪造 告警】\n{NoticeTime: '$t'}\n'${content}'"
      },
     "at": {
        "isAtAll": true
     }
    }'
}
#主程序开始
cd $dir
get_xff
diff 
back_fecth
echo "---XFF伪造可疑ip---"
cat ${warn_ip}

if [ -s ${send_txt} ];then
   dd_send
else
  echo "nothing"
fi
exit 0
