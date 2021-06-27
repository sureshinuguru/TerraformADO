# Terraform Azure

Deployment of Azure infrastructiure using Terraform and ADO

1) What are different artifacts you need to create - name of the artifacts and its purpose
   main.tf - terraform file to create all azure devops resources 
  
2) List the tools you will to create and store the Terraform templates.
     - Git Hub - store terraform script
	 - Terraform
3) Explain the process and steps to create automated deployment pipeline.

   Whenever the code check in to master branch then the pipeline will trigger and deploy the desired infrastructure
   Azure piple lines  - to create stage and steps for run the terraform init,plan and deploy to deploy infrastructure  
4) Create a sample Terraform template you will use to deploy Below services:
Vnet
2 Subnet
NSG to open port 80 and 443
1 Window VM in each subnet
1 Storage account
5) Explain how will you access the password stored in Key Vault and use it as Admin Password in the VM
Terraform template. 

first we need to create depends on with Azure key valut

then we pass the secretpassword from azure key vault
depends_on = [ azurerm_key_vault.kv1 ]
admin_password      = azurerm_key_vault_secret.vmpassword.value