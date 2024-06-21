#!/bin/bash

# Parameterize the input variables
input_path=$1
architecture=$2
operating_system=$3
pvcos_changes=$4

# Define paths
rpm_file_path1="/root/powervc-opsmgr-2.1.1.1/images/powervc-2.1.1.1/packages/osp/python3/noarch"
dest_dir="final_packages"
output_file="output.txt"
filtered_output_file="filtered_output.txt"
declare -A keyword_map

# Define the keyword mappings
keyword_map["monitor"]="ceilometer"
keyword_map["block"]="cinder"
keyword_map["image"]="glance"
keyword_map["identity"]="keystone"
keyword_map["compute"]="nova"
keyword_map["network"]="neutron"

# Function to check if files exist and extract the .tgz file
extract_files() {
    echo "Download the .tgz file and changelog.txt"
    wget "${input_path}/powervc-opsmgr-${operating_system}-${architecture}-2.1.1.1.tgz"
    wget "${input_path}/changelog.txt"
    echo "List current directory to verify downloads"
    ls
    echo "checking if both the files are existing or not"
    if [ -f "powervc-opsmgr-${operating_system}-${architecture}-2.1.1.1.tgz" ] && [ -f "changelog.txt" ]; then
        echo "Files exist."
    else
        echo "One or both files do not exist."
        exit 1
    fi
    echo "Extract the .tgz file"
    tar -zxvf "powervc-opsmgr-${operating_system}-${architecture}-2.1.1.1.tgz"
    if [ $? -ne 0 ]; then
        echo "Error: Extraction failed!"
        exit 1
    fi
}

# Function to process changelog.txt and copy RPM files
process_files() {
    echo "seeing the content in changelog.txt, finding the required keyword in 2nd column of changelog.txt and appending it to another file named output.txt"
    cat changelog.txt | grep Component | awk -F " " '{print $2}' > output.txt
    echo "checking whether the prioritized keywords are found in output.txt or not "
    cat output.txt
    echo "assigned output.txt to a variable name filename for further operations"
    filename="output.txt"
    echo "assigned .rpm to a variable name extension for further operations"
    extension=".rpm"
    echo "created a new directory final_packages and assigned it to a variable name dest_dir"
    dest_dir="final_packages"
    mkdir -p "$dest_dir"
    echo "Destination directory: $dest_dir"
    ls -l
    echo "assigned the .rpm packages where they are present to a variable name rpm_file_path"
    rpm_file_path="/root/powervc-opsmgr-2.1.1.1/images/powervc-2.1.1.1/packages/powervc/python3/noarch"
    echo "Read each line from output.txt i.e., filename and process accordingly"
    while IFS= read -r keyword; do
        echo "Searching for keyword: $keyword"
        # Find .rpm packages that match the keyword and copy them to the destination directory
        find "$rpm_file_path" -type f -name "*$extension" -name "*$keyword*" -exec cp {} "$dest_dir" \; -exec echo "Copied {} to $dest_dir" \;
    done < "$filename"
}

# Function to handle pvcos changes
handle_pvcos_changes() {
    echo "Find .rpm files, filter by python keyword, and extract second column"
    find "$rpm_file_path1" -type f -name "*.rpm" -exec basename {} \; | grep -E "^.*python3.*$" >> "$output_file"

    # Initialize filtered_output.txt
    > "$filtered_output_file"
    # Read output.txt and filter based on keywords
    while IFS= read -r line; do
        word2=$(basename "$line" | awk -F'-' '{print $2}')
        word3=$(basename "$line" | awk -F'-' '{print $3}')

        # Loop through the keyword map and check if word2 matches any of the mapped keywords and word3 is numeric
        for keyword in "${!keyword_map[@]}"; do
            if [[ "$word2" == "${keyword_map[$keyword]}" && "$word3" =~ ^[0-9]+ ]]; then
                echo "$line" >> "$filtered_output_file"
                break
            fi
        done
    done < "$output_file"

    echo "Package extraction completed."
}

# Main script execution
echo "Define the input path"
echo "listing down the files"
ls
extract_files
process_files

# Check the value of pvcos_changes
if [ "$pvcos_changes" = "yes" ]; then
    echo "pvcos changes detected, running additional processing"
    handle_pvcos_changes
else
    echo "No pvcos changes, skipping additional processing"
fi

echo "Additional code to change directory to final_packages"
script_dir=$(dirname "$(realpath "$0")")
cd "$script_dir/$dest_dir"
pwd
echo "checking the source directory files count"
cd "$rpm_file_path"
echo "Number of files in source directory:"
ls -1 | wc -l
echo "validating the count of .rpm packages that are copied from the source to destination directory of final_packages i.e., dest_dir"
cd "$script_dir/$dest_dir"
echo "Number of files in destination directory:"
ls -1 | wc -l
echo "Package extraction completed."

