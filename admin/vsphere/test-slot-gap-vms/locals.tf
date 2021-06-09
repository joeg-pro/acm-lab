locals {
  vcenter_username = var.vcenter_user     == "" ? chomp(file(var.vcenter_user_file))     : var.vcenter_user
  vcenter_password = var.vcenter_password == "" ? chomp(file(var.vcenter_password_file)) : var.vcenter_password
}
 
