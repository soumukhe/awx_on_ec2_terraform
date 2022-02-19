# Installing AWX on EC2

This Terraform code will install an AWS EC2 with AWX, ready to be used.

Please see: https://unofficialaciguide.com for full details

# What is AWX
AWX is the Open-Sourced foundation of Ansible Tower. Ansible was purchased by Red Hat around 2015 and its product Ansible Tower is a commercial version based on AWX maintained and supported by Red Hat. Ansible AWX and Ansible Tower have extremely similar features, though AWX lacks the obvious integration into the Red Hat ecosystem.

The AWX foundation has announced plans to keep the projects "lock and step" in terms of its main features. You will have to decide which platform is correct for your environment.


# Procedures:

This procedure will create everything for you and install AWX ready to be used. It will create objects on AWS, such as VPCs, CIDRs, Subnets, Internet Gateway, Security Groups and EC2. It will also install doker, docker-compose, Ansible and get the scripts ready in the home directory. You just have to ssh in to the EC2 and run those scripts (which are numbered, 1.x, 2,x, 3.x, 4.x).

The actual bringup should not take more than 10 minutes. Before you start, go to the AWS console and create a AWS Key and Secret, which you will need to enter in the "override.tf" file before running the script.

⚠️ The Security Group rules confiugurd by this script are wide open because this is for a POC. If you wanted to tighten it down, please change the terraform resource definition in main.tf before executing the script.


```
1) from the linux/mac box where you will do the install from, make sure you have terraform binary installed
          a) browse to https://terraform.io/downloads,  go to the bottom and right-click and copy the terraform binary for your platform
          b) on your mac or linux box,  do a curl -O <the copied buffer>
          c) unzip the file that you just curled in.  e.g.  unzip terraform_1.1.6_linux_386.zip
          d) sudo mv terraform /usr/local/bin

2) clone this directory:   git clone https://github.com/soumukhe/awx_on_ec2_terraform.git
3) cd awx_on_ec2_terraform.git
4) vi overfide.tf and put in your AWS access-keys and secret keys and awx desired password

5) run the terraform script:
      a) terraform init
      b) terraform validate
      c) terraform apply

6) the output on the screen will give you the ec2 Public IP.  SSH to the ec2 with ec2-user@publicIP and run the following scripts:
     ./1.runansible_play.sh  # this ansible playbook will take 5 minutes to run
     ./2.install_galay_awx_task.sh
     ./3.install_galaxy-awx_web.sh
     ./4.create_aci_dir.sh

7) Now you can browse to your awx ui.   Point browser to http://public_IP of ec2.   
     a) you can do a terraform output from the terraform worksapce directory (where you ran the terraform plan from) to see the public ip
     b) the username will be admin and the password will be the one you specified in the overide.tf file

8)  To Destroy:
     for full AWS constructs this script built:  terraform destroy
     to just destroy the ec2:   terraform destroy --target aws_instance.dummy-phy-ec2


```
