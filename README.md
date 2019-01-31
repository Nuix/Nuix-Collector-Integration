Nuix Collector Integration
===============

![This script was last tested in Nuix 7.4](https://img.shields.io/badge/Script%20Tested%20in%20Nuix-7.4-green.svg)

View the GitHub project [here](https://github.com/Nuix/Nuix-Collector-Integration) or download the latest release [here](https://github.com/Nuix/Nuix-Collector-Integration/releases).

# Overview

This script will generate a Nuix Collector XML job file based on items located in one or more Nuix cases.  The job file created can be used for defensible remediation of the items' source data on disk.  Items are located based on a user provided scope query.  This script can optionally also run remediation through Nuix Collector.

# Settings

## Main Tab

| Setting | Description |
| ------- | ----------- |
| **Cases Directory** | A root directory containing one or more Nuix cases.  This directory will be searched for Nuix cases, each of which the script will process. |
| **Allow Case Migration** | When checked, will perform a case migration if required. |
| **Output Directory** | The root output directory.  A sub directory will be created for each case processed named `CASENAME-CASEGUID`. |
| **Collector Executable** | Location of `Nuix Collector.exe`.  Required if you wish to have the script perform deletions as it goes (when **Perform Deletions with Collector** is checked). |
| **Collector Job Template** | Path to a template Nuix Collector XML job file. |
| **Run Job in Collector Once Generated** | When checked, after each job file is created for each case, the script will pass the job file over to Nuix Collector to begin deletion.  *Leave this unchecked to just create the job files!* |
| **Scope** | A Nuix query which determines which items to record/delete.  The default is `flag:physical_file` because the script can only get file system paths to items which exist on the file system (Physical Files).  It is recommended that your scope query contain at least this criteria, but may contain additional criteria to further refine which items are processed. |


## Operate As Tab

Settings on this tab allow you to provide credentials, for example if the files reside on a UNC which requires authentication.  Note that values (including password!) are stored as plain text in the resulting job file and in the settings JSON file if save your settings using `File -> Save Settings`.

| Setting | Description |
| ------- | ----------- |
| **User Name** | User name |
| **Domain** | Domain to authenticate user against |
| **Password** | Password |


## Remediation Tab
### Remediation Type
Select the type of remediation to perform on files responsive to the Scope query

| Setting | Description | Attribute Settings | File Ownership Settings | Copy Settings | Compression/Encryption Settings | Destruction Settings |
| ------- | ----------- | :----------------: | :---------------------: | :-----------: | :-----------------------------: | :------------------: |
| **Delete Files** | Deletes files | N | N | N | N | Y |
| **Move Files** | Relocates files to Copy Destination Directory | Y | Y | Y | Y | Y |
| **In Place** | Updates files in place | Y | Y | N | Y | N |
| **Copy** | Copies files to Copy Destination Directory | Y | Y | Y | Y | N |

### Attribute Settings
Allows the modification of file RASH (Read Only, Archive, System, and Hidden) attributes.
### File Ownership Settings
Allows the file owner to be modified.
### Copy Settings
Defines the Copy Destination Directory where files will be copied to. Select the Overwrite While Copying checkbox to overwrite files in the Copy Destination Directory.
### Compression/Encryption Settings
Allows the files to be compressed into a zip container and optionally encrypted using the supplied password.
### Destruction Settings
After a file is deleted, the file can often be undeleted using various undelete utilities. These utilities must read residual data within the file system to recover the deleted file. These settings allow you to randomize this data, to prevent successful undeletion.


| Setting | Description |
| ------- | ----------- |
| **Scramble Creation Date** | Specifies whether to scramble the created date of each file being deleted.  This effects the file allocation table. |
| **Scramble Modification Date** | Specifies whether to scramble the modified date of each file being deleted.  This effects the file allocation table. |
| **Scramble Access Date** | Specifies whether to scramble the last access date of each file being deleted.  This effects the file allocation table. |
| **Scramble Name** | Specifies whether to scramble the name of each deleted file with random data. This effects the file allocation table. |
| **Delete Folders** | Specifies whether to delete any folders which were emptied by the current deletionjob. Can be `Yes` or `No`.  A value of `Yes` (checked) deletes any folders which were emptied by the current deletion job.  A value of `No` (unchecked) will leave any folders emptied by the program. |
| **Overwrite Count** | Specifies the number of times to overwrite the previously allocated sectors (the content) of each deleted file with random data. Valid values are `0` to `7`.  Each overwrite cycle takes time. A value of `0` (no overwrite) runs fastest, but leaves open the possibility of being able to undelete the file's content. A value of `1` renders the file content permanently deleted; however, some extremely sophisticated recovery equipment can possibly detect traces of old file patterns. Various military standards require from `2` to `7` overwrite cycles to securely wipe data. |


## Verification Settings Tabs

| Setting | Description |
| ------- | ----------- |
| **Verify File Existence** | The script will validate the existence of each file, skipping (and recording in a separate file) files which were not able to be located. |
| **Verify Creation Date** | Inserts the creation date of each file into the file list.  Nuix Collector will use this to verify that the file has the same value before deletion.  If the value differs, deletion of the differing file will be skipped. |
| **Verify Modification Date** | Inserts the modification date of each file into the file list.  Nuix Collector will use this to verify that the file has the same value before deletion.  If the value differs, deletion of the differing file will be skipped. |
| **Verify Access Date** | Inserts the last access date of each file into the file list.  Nuix Collector will use this to verify that the file has the same value before deletion.  If the value differs, deletion of the differing file will be skipped. |
| **Verify Size** | Inserts the file size of each file into the file list.  Nuix Collector will use this to verify that the file has the same value before deletion.  If the value differs, deletion of the differing file will be skipped. |
| **Verify MD5 Hash** | Inserts the MD5 hash of each file into the file list.  Nuix Collector will use this to verify that the file has the same value before deletion.  If the value differs, deletion of the differing file will be skipped.  **Note:**  This will cost performance (CPU time) since Nuix Collector will need to independently generate an MD5 hash for each file to compare to the known value. |


## File List Output Tab

| Setting | Description |
| ------- | ----------- |
| **Limit Entries Per File List** | Determines how many file entries per text or xml file list.  As a given file hits this maximum threshold, further file entries will be rolled into a new sequentially numbered file. |
| **Create File List as Text** | When checked file lists will be generated in the text file format.  When unchecked file lists will be generated in the XML fiile format.  This also yields appropriately built XML job file. |


# Template File

The generated XML job file is based on a user provided template file.  A good default is included with the script (`DefensibleForensicDeletionTemplate.xml`).  The template XML file is rendered to a final version by replacing certain placeholders within the template file.  Full documentation for the Nuix Collector job file format can be found [here](https://download.nuix.com/system/files/Nuix%20Collector%20and%20ECC%20JobFile%20Reference%20Guide%20v7.2_5.pdf).

| Template Placeholder | Replacement Value |
| -------------------- | ----------------- |
| `~BASEFILELISTNAME~` | `FileList {DateTime}` when using text based file lists, `XML FileList {DateTime}` when using XML based file lists
| `~OUTPUTLOGDIRECTORY~` | Replaced with a path to a sub directory named `CASENAME-CASEGUID` within the selected **Output Directory**
| `~INVESTIGATOR~` | Replaced with the investigator name in the Nuix Case.
| `~CASENAME~` | Replace with the Nuix Case name.
| `~OVERWRITECOUNT~` | Value provided in setting **Overwrite Count**
| `~SCRAMBLECREATIONDATE~` | `Yes` or `No` depending on whether **Scramble Creation Date** is checked |
| `~SCRAMBLEMODIFICATIONDATE~` | `Yes` or `No` depending on whether **Scramble Modification Date** is checked |
| `~SCRAMBLEACCESSDATE~` | `Yes` or `No` depending on whether **Scramble Access Date** is checked |
| `~SCRAMBLENAME~` | `Yes` or `No` depending on whether **Scramble Name** is checked |
| `~DELETEFOLDERS~` | `Yes` or `No` depending on whether **Delete Folders** is checked |
| `~USERNAME~` | The value provided for the setting **User Name** (can be empty string) |
| `~DOMAIN~` | The value provided for the setting **Domain** (can be empty string) |
| `~PASSWORD~` | The value provided for the setting **Password** (can be empty string) |
| `~FILELIST~` | Will be a list of file paths pointing either towards the various text based file lists that were generated or the various XML based file lists that were generated, depending on whether **Create File List as Text** was checked. |
