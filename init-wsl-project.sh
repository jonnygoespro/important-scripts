#!/bin/bash

# Check for sudo usage
if [ "$EUID" -ne 0 ]; then
	echo 'Error: Please run the script as sudo'
	exit 1
fi

project_name=''
repo=''
win_user="Jonas"
linux_user="jonny"
source_folder="/mnt/c/Users/$win_user/dev/prv/"

# Check if windows user exists
if [ ! -d "/mnt/c/Users/$win_user" ]; then
	echo "Error: User $win_user does not exist on Windows"
	exit 1
fi

# Check if linux user exists
if [ ! -d "/home/$linux_user" ]; then
	echo "Error: User $linux_user does not exist on Linux"
	exit 1
fi


# Check if source folder exists
if [ ! -d "$source_folder" ]; then
	echo "Error: Source folder does not exist"
	exit 1
fi

# Print Usage for script
print_usage() {
	echo "Usage: sudo ./init-project.sh -n <project_name> -c <git_repository>"
}

while getopts 'n:c:' flag; do
	case "${flag}" in
		n) project_name="${OPTARG}" ;;
		c) repo="${OPTARG}" ;;
		*) print_usage
		   exit 1 ;;
	esac
done

# Stop Execution if project_name is empty
if [ "$project_name" == '' ]
then
	print_usage
	exit 1
fi

# Stop execution of project already exists
if [ -d "$source_folder$project_name" ]; then
	echo 'Error: This project already exists'
	exit 1
fi

# Clone repo if wanted
if [ "$repo" != "" ]; then
	sudo -u $linux_user git clone $repo "$source_folder$project_name"
	echo "Repository cloned on Windows"
else
	# Create Folder on windows
	if [ -d "$source_folder" ]; then
		mkdir -p "$source_folder$project_name"
		echo "Folder created on Windows"
	else 
		echo "Error: Setup directory on windows not found"
		exit 1
	fi
fi

# Create symlink on subsystems
ln -s "$source_folder$project_name" "./$project_name"
echo "Symlink created on subsystems"

# Start apache
service apache2 start

# Setup virtual host
cat << EOF >> /etc/apache2/sites-available/$project_name.localhost.conf
<VirtualHost *:80>
	ServerAdmin webmaster@localhost
	DocumentRoot /home/$linux_user/sites/$project_name/dist/
	ServerName $project_name.localhost

        <Directory /home/$linux_user/sites/$project_name/dist/>
	        Require all granted
	</Directory>
	
	ErrorLog \${APACHE_LOG_DIR}/error.log
	CustomLog \${APACHE_LOG_DIR}/access.log combined

	ErrorDocument 404 /index.html
</VirtualHost>	
EOF

# Enable site
a2ensite "$project_name.localhost.conf"

# Reload apache
service apache2 restart

# Success
echo 'Success'
exit 0
