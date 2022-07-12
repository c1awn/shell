#!/bin/sh 
#set -x
ns=namespace
service=test
exclude=test-admin
out=/tmp/pod_per.txt
#$limit是container_memory_working_set_bytes=container_memory_usage_bytes - total_inactive_file
limit=0.9
#$unsafe是内存百分比超过$limit的pod数量/总pod数量
unsafe=0.5

alias kget='kubectl get pods -n $ns '
alias kexec='kubectl exec  -n $ns '
alias kcp='kubectl cp  -n $ns  '
alias kdes='kubectl describe deployments -n $ns '

#获取所有pod的内存使用率
get_per(){
>$out
for pod in `kget |grep $service|grep -v $exclude|awk '{print $1}'|xargs`;do 
  #如果用cron，容器cat得到的换行可能不是\r\n，而是\n
  per=`kexec $pod -- cat  /sys/fs/cgroup/memory/memory.usage_in_bytes /sys/fs/cgroup/memory/memory.limit_in_bytes /sys/fs/cgroup/memory/memory.stat|sed ':a;N;s/\r\n/\t/;ba;'|awk '{printf "%g\n",($1-$(NF-4))/$2}'`
  echo $pod $per >>$out
done
}

#重启pod函数，不推荐
life(){
  num=`kdes kmsp-deployment-${service} |grep desired|awk '{print $2}'`
  kubectl scale deployment kmsp-deployment-${service} --replicas=0 -n $ns
  kubectl scale deployment kmsp-deployment-${service} --replicas=$num -n $ns
}

#滚动重启，推荐
new(){
  kubectl rollout restart deployment  kmsp-deployment-${service} -n $ns
}


#比较满足条件的pod数，超过即重启pod
diff(){
  result=`awk '{if($NF>='$limit'){a+=1;}}END{print a/NR}' $out`
  #浮点和整数比较
  [[ $(echo "$result > $unsafe"|bc) -eq 1 ]]&&echo $result&&new
}

get_per
diff
exit 0
