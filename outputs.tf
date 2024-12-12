output "ipzabbix" {
  value = aws_instance.lin_zabbix.public_ip
}
output "ipprivzab" {
  value = aws_instance.lin_zabbix.private_ip
}
output "urlzabbix" {
  value = "http://${aws_instance.lin_zabbix.public_ip}/zabbix"
}
output "urlgrafana" {
  value = "http://${aws_instance.lin_zabbix.public_ip}:3000"
}