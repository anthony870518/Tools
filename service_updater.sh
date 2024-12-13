#!/bin/bash

# Find the tar.gz file in /root/dist excluding those containing 'sap'
file=$(ls /root/dist | grep tar.gz | grep -v sap)
original_file_name=$file
id=${file%.tar.gz}
product=$(ls /root/dist/ | grep batch.sql | sed 's/batch\.sql//')
if [ -n "$file" ]; then
  # Check the contents of the tar file
  if tar -tf /root/dist/$file | grep -q "table_xxxxx.js"; then
    # Get the last modified date of the file in YYYYMMDD format
    modified_date=$(date -r /root/dist/$file +%Y%m%d)

    # Determine the new file name with a unique suffix if it already exists
    new_file="/root/dist/bak/${file}-${modified_date}"
    n=1
    while [ -e "$new_file" ]; do
      new_file="/root/dist/bak/${file}-${modified_date}-${n}"
      n=$((n+1))
    done

    # Move and rename the file
    mv /root/dist/$file "$new_file"
    echo "Moved and renamed: $new_file"
  else
    modified_date=$(date -r /root/dist/$file +%Y%m%d)
    # Determine the new file name with a unique suffix if it already exists
    new_file="/root/dist/bak/${file}-${modified_date}-account"
    n=1
    while [ -e "$new_file" ]; do
      new_file="/root/dist/bak/${file}-${modified_date}-account-${n}"
      n=$((n+1))
    done

    # Rename the file to indicate it does not contain 'table_xxxxx.js'
    mv /root/dist/$file "$new_file"
    echo "Moved and renamed: $new_file"
  fi
else
  echo "No matching tar.gz file found in /root/dist"
fi

# Check for multiple .tar.gz files in the current directory
tar_files=( *.tar.gz )
if [ ${#tar_files[@]} -gt 1 ]; then
  echo "Multiple tar.gz files found, please keep only one."
  exit 1
else
  tar_file=(*.tar.gz)
fi

# Check if the file exists to avoid wildcard expansion issue
if [ -f "$tar_file" ]; then
  echo "Checking $tar_file..."

  # Get the list of files inside the tar.gz archive
  file_list=$(tar -tf "$tar_file")

  # Check for specific patterns in the extracted files
  if [[ "$file_list" =~ mg_conf_user_info_.*\.sql$ ]]; then
    echo "$tar_file is for 帳號發布, will be renamed as $original_file_name"
    mv "$tar_file" "/root/dist/$original_file_name"
    echo "src_tar $tar_file des_tar:$original_file_name ID:$id Product:$product"
    sudo sh -c "cd /root/dist && ./release.sh 2 $id $product"
  elif [[ "$file_list" =~ table_.*\.js$ ]]; then
    echo "$tar_file is for 業務發佈, will be renamed as $original_file_name"
    mv "$tar_file" "/root/dist/$original_file_name"
    echo "src_tar $tar_file des_tar:$original_file_name ID:$id Product:$product"
    sudo sh -c "cd /root/dist && ./release.sh 1 $id $product"
  else
    echo "$tar_file does not match either criteria."
  fi
else
  echo "No .tar.gz files found in the current directory."
fi

