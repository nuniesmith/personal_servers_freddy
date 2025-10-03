#!/bin/bash
# Samba User Management Script for Freddy Server

echo "Samba User Management for Audiobooks Share"
echo "==========================================="

# Function to add a new SMB user
add_user() {
    echo "Adding new SMB user..."
    read -p "Enter username: " username
    read -s -p "Enter password: " password
    echo
    
    # Add user to the Samba container
    docker exec -it samba sh -c "echo '$password' | tee - | smbpasswd -a '$username' -s"
    
    if [ $? -eq 0 ]; then
        echo "User '$username' added successfully!"
        echo "You can now connect to the SMB share using:"
        echo "  Server: //$(hostname -I | awk '{print $1}')/Audiobooks"
        echo "  Username: $username"
        echo "  Password: (the one you just entered)"
    else
        echo "Failed to add user '$username'"
    fi
}

# Function to remove an SMB user
remove_user() {
    echo "Removing SMB user..."
    read -p "Enter username to remove: " username
    
    docker exec -it samba smbpasswd -x "$username"
    
    if [ $? -eq 0 ]; then
        echo "User '$username' removed successfully!"
    else
        echo "Failed to remove user '$username'"
    fi
}

# Function to list SMB users
list_users() {
    echo "Current SMB users:"
    docker exec -it samba pdbedit -L
}

# Main menu
while true; do
    echo
    echo "Choose an option:"
    echo "1. Add SMB user"
    echo "2. Remove SMB user"
    echo "3. List SMB users"
    echo "4. Exit"
    echo
    read -p "Enter your choice (1-4): " choice
    
    case $choice in
        1) add_user ;;
        2) remove_user ;;
        3) list_users ;;
        4) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice. Please try again." ;;
    esac
done