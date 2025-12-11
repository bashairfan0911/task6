output "public_ip" {
  value = aws_instance.strapi.public_ip
}
 
output "strapi_url" {
  value = "http://${aws_instance.strapi.public_dns}:${var.strapi_port}"
}