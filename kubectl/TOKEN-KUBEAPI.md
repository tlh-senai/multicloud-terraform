## COMANDOS PARA OBTER TOKEN DA API TERRAFORM
1.
kubectl create serviceaccount zabbix-monitor -n default
kubectl create clusterrolebinding zabbix-monitor-binding --clusterrole=cluster-admin --serviceaccount=default:zabbix-monitor

2.
kubectl apply -f pjfinal-secret.yaml

3.
kubectl get secret zabbix-monitor-token
kubectl describe secret zabbix-monitor-token

Para o GitHub Actions
kubectl get secret zabbix-monitor-token -o yaml