output "public_ip_of_ansible_host" {
  value = aws_instance.ansible_host.public_ip
}

output "public_ip_of_ansible_target" {
  value = module.ansible_target["first"].public_ip
}
