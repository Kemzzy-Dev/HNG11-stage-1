#!/bin/bash

# Log file location
LOGFILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Check if the input file is provided
if [ -z "$1" ]; then
  echo "Error: No file was provided"
  echo "Usage: $0 <name-of-text-file>"
  exit 1
fi

# Create log and password files
mkdir -p /var/secure
touch $LOGFILE $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Function to create a user
create_user() {
  local username=$1
  local groups=$2

  if id "$username" &>/dev/null; then
    echo "User $username already exists" | tee -a $LOGFILE
  else
    useradd -m $username
    echo "Created user $username" | tee -a $LOGFILE
  fi

  # Create a personal group for the user
  if ! getent group "$username" &>/dev/null; then
    groupadd "$username"
    usermod -aG "$username" "$username"
    echo "Created personal group $username for user $username" | tee -a $LOGFILE
  fi

  # Add user to specified groups
  IFS=',' read -ra GROUPS <<< "$groups"
  for group in "${GROUPS[@]}"; do
    if ! getent group "$group" &>/dev/null; then
      groupadd "$group"
      echo "Created group $group" | tee -a $LOGFILE
    fi
    usermod -aG "$group" "$username"
    echo "Added user $username to group $group" | tee -a $LOGFILE
  done

  # Set up home directory permissions
  chmod 700 /home/$username
  chown $username:$username /home/$username
  echo "Set up home directory for user $username" | tee -a $LOGFILE

  # Generate a random password
  local password=$(openssl rand -base64 12)
  echo "$username:$password" | chpasswd
  echo "$username,$password" >> $PASSWORD_FILE
  echo "Set password for user $username" | tee -a $LOGFILE
}

# Read the input file and create users
while IFS=';' read -r username groups; do
  create_user "$username" "$groups"
done < "$1"

echo "User creation process completed." | tee -a $LOGFILE
