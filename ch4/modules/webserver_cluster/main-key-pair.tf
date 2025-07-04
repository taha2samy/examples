
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "ec2_key_pair_pem" {
  content         = tls_private_key.ec2_key.private_key_pem
  filename        = "./ec2_key.pem"
  file_permission = "0400"
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "my-ec2-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}