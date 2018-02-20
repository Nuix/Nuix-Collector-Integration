# Menu Title: Nuix Collector Integration
# Needs Case: false
# Needs Selected Items: false

# This essentially "bootstraps" the library from a Ruby script
script_directory = File.dirname(__FILE__)
require File.join(script_directory,"Nx.jar")
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.CustomDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.dialogs.ProcessingStatusDialog"
java_import "com.nuix.nx.digest.DigestHelper"
java_import "com.nuix.nx.controls.models.Choice"

java_import java.lang.Runtime
java_import java.io.BufferedReader
java_import java.io.InputStreamReader

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

load File.join(script_directory,"RollingFileWriter.rb")
load File.join(script_directory,"RollingXmlFileWriter.rb")
load File.join(script_directory,"Helpers.rb")
load File.join(script_directory,"CollectorJob.rb")

# Build settings dialog
dialog = TabbedCustomDialog.new("Nuix Collector Integration")
dialog.setSize(1024,850)
dialog.setHelpFile(File.join(script_directory,"Readme.html"))

#==========#
# Main Tab #
#==========#
main_tab = dialog.addTab("main_tab","Main")
main_tab.appendDirectoryChooser("cases_directory","Cases Directory")
main_tab.appendCheckBox("allow_migration","Allow Case Migration",false)
main_tab.appendDirectoryChooser("output_directory","Output Directory")
main_tab.appendOpenFileChooser("collector_exe","Collector Executable","Collector Executable","exe")
main_tab.getControl("collector_exe").setPath("C:\\Program Files (x86)\\Nuix\\Nuix Collector\\Modules\\Nuix Collector.exe")
main_tab.appendOpenFileChooser("job_template_file","Collector Job Template","Collector Job Template XML","xml")
main_tab.getControl("job_template_file").setPath(File.join(script_directory,"CollectorJobTemplate.xml").gsub(/\//,"\\"))
main_tab.appendCheckBox("run_collector_job","Run Job in Collector Once Generated",true)
main_tab.appendTextArea("scope_query","Scope","flag:physical_file")

#=================#
# Credentials Tab #
#=================#
credentials_tab = dialog.addTab("credentials_tab","Operate As")
credentials_tab.appendTextField("username","User Name","")
credentials_tab.appendTextField("domain","Domain","")
credentials_tab.appendPasswordField("password","Password","")

#=================#
# Remediation Tab #
#=================#
remediation_choices = {
	"Delete Files (no copy, yes delete)" => {:copy => false, :delete => true},
	"Move Files (yes copy, yes delete)" => {:copy => true, :delete => true},
	"In Place (no copy, no delete)" => {:copy => false, :delete => false},
	"Copy (yes copy, no delete)" => {:copy => true, :delete => false},
}
remediation_tab = dialog.addTab("remediation_tab","Remediation")
remediation_tab.appendComboBox("remediation_choice","Remediation Type",remediation_choices.keys)

# Settings regarding changing attributes, either in place or of copies
remediation_tab.appendSeparator("Attribute Settings")
attributes = {
	"r" => "Read Only",
	"a" => "Archive",
	"s" => "System",
	"h" => "Hidden"
}
attributes.each do |attribute,description|
	attribute_choices = {
		"No Change" => "ignore_attribute_#{attribute}",
		"Add" => "add_attribute_#{attribute}",
		"Remove" => "remove_attribute_#{attribute}",
	}
	remediation_tab.appendRadioButtonGroup("Attribute #{attribute.upcase} (#{description})","attr_#{attribute}_group",attribute_choices)
end

# Settings regarding change of file ownership
remediation_tab.appendSeparator("File Ownership Settings")
remediation_tab.appendCheckBox("change_file_owner","Change File Owner",false)
remediation_tab.appendTextField("new_file_owner","New File Owner (DOMAIN\\USER)","")
remediation_tab.enabledOnlyWhenChecked("new_file_owner","change_file_owner")

# Settings regarding the copy process
remediation_tab.appendSeparator("Copy Settings")
remediation_tab.appendDirectoryChooser("extract_path_directory","Copy Destination Directory")
remediation_tab.appendCheckBox("overwrite_while_copying","Overwrite While Copying",false)

# Settings regarding compressing and potentially encrypting files
remediation_tab.appendSeparator("Compression/Encryption Settings")
remediation_tab.appendCheckBox("compress_files","Compress Files",false)
remediation_tab.appendSpinner("compression_level","Compression Level",0,0,9)
remediation_tab.appendCheckBox("encrypt_files","Encrypt Files",false)
remediation_tab.appendPasswordField("encryption_password","Encryption Password","")

remediation_tab.enabledOnlyWhenChecked("compression_level","compress_files")
remediation_tab.enabledOnlyWhenChecked("encrypt_files","compress_files")
remediation_tab.enabledOnlyWhenChecked("encryption_password","compress_files")

# Settings regarding how deletion is performed
# remediation_tab.appendSeparator("Destruction Settings")
# remediation_tab.appendCheckBox("scramble_creation_date","Scramble Creation Date",false)
# remediation_tab.appendCheckBox("scramble_modification_date","Scramble Modification Date",false)
# remediation_tab.appendCheckBox("scramble_access_date","Scramble Access Date",false)
# remediation_tab.appendCheckBox("scramble_name","Scramble Name",false)
# remediation_tab.appendCheckBox("delete_folders","Delete Folders",false)
# remediation_tab.appendSpinner("overwrite_count","Overwrite Count",0,0,7) # Valid values are 0-7

remediation_tab.appendSeparator("Destruction Settings")
remediation_tab.appendCheckBoxes(
	"scramble_creation_date","Scramble Creation Date",false,
	"scramble_modification_date","Scramble Modification Date",false)
remediation_tab.appendCheckBoxes(
	"scramble_access_date","Scramble Access Date",false,
	"scramble_name","Scramble Name",false)
remediation_tab.appendCheckBox("delete_folders","Delete Folders",false)
remediation_tab.appendSpinner("overwrite_count","Overwrite Count",0,0,7) # Valid values are 0-7

# Enable/disable choices based on remediation selection.  Mostly this means does the selected
# remediation choice involve copying and/or deletion or potentially neither
def enable_disable_remediation_settings(remediation_choices,remediation_tab)
	# Get whether selected remediation choice involves copying and/or deletion or potentially neither
	data = remediation_choices[remediation_tab.getText("remediation_choice")]
	copy = data[:copy]
	delete = data[:delete]

	# Only valid when making a copy of the files
	remediation_tab.getControl("extract_path_directory").setEnabled(copy)
	remediation_tab.getControl("overwrite_while_copying").setEnabled(copy)
	
	# Only valid when performing deletion
	remediation_tab.getControl("scramble_creation_date").setEnabled(delete)
	remediation_tab.getControl("scramble_modification_date").setEnabled(delete)
	remediation_tab.getControl("scramble_access_date").setEnabled(delete)
	remediation_tab.getControl("scramble_name").setEnabled(delete)
	remediation_tab.getControl("delete_folders").setEnabled(delete)
	remediation_tab.getControl("overwrite_count").setEnabled(delete)

	# Some controls are only relevant if a copy is being made or not deletion is occurring, basically
	# they are not valid if the operation is to just delete the files
	if copy || (!copy && !delete)
		compression_settings_enabled = true
	else
		compression_settings_enabled = false
	end

	# Compression and encryption only enabled when not performing a full deletion without copy
	remediation_tab.getControl("compress_files").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("compression_level").setEnabled(compression_settings_enabled && remediation_tab.isChecked("compress_files"))
	remediation_tab.getControl("encrypt_files").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("encryption_password").setEnabled(compression_settings_enabled && remediation_tab.isChecked("encrypt_files"))

	# Attributes adhere to same rule, only enabled when not performing a full deletion without copy
	remediation_tab.getControl("add_attribute_r").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("add_attribute_a").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("add_attribute_s").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("add_attribute_h").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("remove_attribute_r").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("remove_attribute_a").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("remove_attribute_s").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("remove_attribute_h").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("ignore_attribute_r").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("ignore_attribute_a").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("ignore_attribute_s").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("ignore_attribute_h").setEnabled(compression_settings_enabled)

	# File owner as well
	remediation_tab.getControl("change_file_owner").setEnabled(compression_settings_enabled)
	remediation_tab.getControl("new_file_owner").setEnabled(compression_settings_enabled && remediation_tab.isChecked("change_file_owner"))
end

# When choice in combo box is modified, enable/disable appropriate controls
remediation_tab.getControl("remediation_choice").addActionListener do
	enable_disable_remediation_settings(remediation_choices,remediation_tab)
end

# Make sure controls are in sync with whatever is selected by default when the dialog is
# initially displayed
enable_disable_remediation_settings(remediation_choices,remediation_tab)

#==================#
# Verification Tab #
#==================#
verification_tab = dialog.addTab("verification_tab","Verification Settings")
verification_tab.appendCheckBox("verify_file_existence","Verify File Existence",false)
verification_tab.appendCheckBox("verify_creation_date","Verify Creation Date",true)
verification_tab.appendCheckBox("verify_modification_date","Verify Modification Date",true)
verification_tab.appendCheckBox("verify_access_date","Verify Access Date",false)
verification_tab.appendCheckBox("verify_size","Verify Size",true)
verification_tab.appendCheckBox("verify_md5_hash","Verify MD5 Hash",false)

#===============#
# File List Tab #
#===============#
file_list_tab = dialog.addTab("file_list_tab","File List Output")
file_list_tab.appendSpinner("entry_limit","Limit Entries per File List",10000,1000,999999999,1000)
file_list_tab.appendCheckBox("create_file_list_as_text","Create File List as Text",false)

# Helper method to determine if we're running as admin
# https://stackoverflow.com/questions/560366/detect-if-running-with-administrator-privileges-under-windows-xp
def running_elevated?
	whoami = `whoami /groups` rescue nil
	if whoami =~ /S-1-16-12288/
		true
	else
		admin = `net localgroup administrators | find "%USERNAME%"` rescue ""
		admin.empty? ? false : true
	end
end

# Convenience method for running a command string in the OS
#
# @param command [String] Command string to execute
# @param use_shell [Boolean] When true, will pipe command through CMD /S /C to enable shell features
# @param working_dir [String] The working directory of the subprocess
def run(command,use_shell=true,working_dir)
  # Necessary if command take advantage of any shell features such as
  # IO piping
  if use_shell
    command = "cmd /S /C \"#{command}\""
  end

  begin
    puts "Executing: #{command}"
    p = Runtime.getRuntime.exec(command,[].to_java(:string),java.io.File.new(working_dir))
    
      # Read error stream
    std_err_reader = BufferedReader.new(InputStreamReader.new(p.getErrorStream))
    while ((line = std_err_reader.readLine()).nil? == false)
      puts line
    end
    
    p.waitFor
    puts "Execution completed:"
    reader = BufferedReader.new(InputStreamReader.new(p.getInputStream))
    while ((line = reader.readLine()).nil? == false)
      puts line
    end
  rescue Exception => e
    puts e.message
    puts e.backtrace.inspect
  ensure
    p.destroy
  end
end

# Define validations which must pass before script will run
dialog.validateBeforeClosing do |values|
	# Make sure user picked a case directory
	if values["cases_directory"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Cases Directory'")
		next false
	end

	# Make sure user picked an output directory
	if values["output_directory"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Output Directory'")
		next false
	end

	# Check collector executable path
	if values["collector_exe"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Collector Executable'")
		next false
	elsif !java.io.File.new(values["collector_exe"]).exists
		CommonDialogs.showWarning("Value provided for 'Collector Executable' does not point to a valid file")
		next false
	end

	# Make sure we have a job template file to work with
	if values["job_template_file"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Collector Job Template'")
		next false
	elsif !java.io.File.new(values["job_template_file"]).exists
		CommonDialogs.showWarning("Value provided for 'Collector Job Template' does not point to a valid file")
		next false
	end

	data = remediation_choices[values["remediation_choice"]]
	copy = data[:copy]
	delete = data[:delete]

	# If copying is involved make sure we have a destination location
	if copy && values["extract_path_directory"].strip.empty?
		CommonDialogs.showWarning("Please provide a value for 'Copy Destination Directory'")
		next false
	end

	# Make user confirm what they are about to do, should be the last validation!
	confirmation_message = "Are you absolutely sure you'd like to proceed knowing that remediation will be performed once job files are generated?"
	if values["run_collector_job"] && CommonDialogs.getConfirmation(confirmation_message) == false
		next false
	end

	# Some settings only play a part if the job isn't just deleting.  These settings are only relevant
	# if we are copying or were doing in-place update
	if copy || (!copy && !delete)
		if values["encrypt_files"] && @encryption_password.size < 4
			CommonDialogs.showWarning("Please provide an encryption password with at least 4 characters in it.")
			next false
		end
	end

	# If we are to run the collector job, make sure user has elevated privileges, without them it seems collector
	# often will not run correctly (based on feedback)
	if values["run_collector_job"] && !running_elevated?
		CommonDialogs.showWarning("It appears Nuix was not run with elevated privileges.  Since you selected to run this job in collector,"+
			" you should save your current settings and restart this script/Nuix as a user with elevated privileges (such as administrator).","Running as Non-elevated User")
		next false
	end

	next true
end

#=============#
# Do the work #
#=============#
dialog.display
if dialog.getDialogResult == true
	values = dialog.toMap
	time_stamp = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
	formatter = org.joda.time.format.DateTimeFormat.forPattern("yyyy-MM-dd'T'HH:mm:ssZZ").withZone(org.joda.time.DateTimeZone.getDefault())

	cases_directory = values["cases_directory"]
	allow_migration = values["allow_migration"]
	output_directory = values["output_directory"]
	job_template_file = values["job_template_file"]
	collector_exe = values["collector_exe"]
	scope_query = values["scope_query"]
	run_collector_job = values["run_collector_job"]

	remediation_settings = remediation_choices[values["remediation_choice"]]
	# puts "DEBUG: remediation_choices = #{remediation_choices}"
	# puts "DEBUG: values[\"remediation_choice\"] = #{values["remediation_choice"]}"
	# puts "DEBUG: remediation_choices[values[\"remediation_choice\"]] = #{remediation_choices[values["remediation_choice"]]}"

	overwrite_while_copying = values["overwrite_while_copying"]
	extract_path_directory = values["extract_path_directory"]
	add_attribute_r = values["add_attribute_r"]
	add_attribute_a = values["add_attribute_a"]
	add_attribute_s = values["add_attribute_s"]
	add_attribute_h = values["add_attribute_h"]
	remove_attribute_r = values["remove_attribute_r"]
	remove_attribute_a = values["remove_attribute_a"]
	remove_attribute_s = values["remove_attribute_s"]
	remove_attribute_h = values["remove_attribute_h"]

	compress_files = values["compress_files"]
	compression_level = values["compression_level"]
	encrypt_files = values["encrypt_files"]
	encryption_password = values["encryption_password"]

	change_file_owner = values["change_file_owner"]
	new_file_owner = values["new_file_owner"]

	username = values["username"]
	domain = values["domain"]
	password = values["password"]

	scramble_creation_date = values["scramble_creation_date"]
	scramble_modification_date = values["scramble_modification_date"]
	scramble_access_date = values["scramble_access_date"]
	scramble_name = values["scramble_name"]
	delete_folders = values["delete_folders"]
	overwrite_count = values["overwrite_count"]

	verify_file_existence = values["verify_file_existence"]
	verify_creation_date = values["verify_creation_date"]
	verify_modification_date = values["verify_modification_date"]
	verify_access_date = values["verify_access_date"]
	verify_size = values["verify_size"]
	verify_md5_hash = values["verify_md5_hash"]

	entry_limit = values["entry_limit"]
	create_file_list_as_text = values["create_file_list_as_text"]

	last_progress = Time.now

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Nuix Collector Integration")
		pd.setAbortButtonVisible(false)

		# Dump many of the settings we are using to console
		puts "Settings:"
		values.each do |key,value|
			puts "\t#{key} => #{value}"
		end

		pd.setMainStatusAndLogIt("Locating cases...")
		fbi2_files = Dir.glob(File.join(cases_directory,"**","case.fbi2"))
		case_directories = fbi2_files.map{|file| File.dirname(file).gsub(/\//,"\\")}
		pd.logMessage("Located #{case_directories.size} cases")

		pd.setMainProgress(0,case_directories.size)
		case_directories.each_with_index do |case_directory,case_index|
			pd.setMainProgress(case_index+1)
			pd.setMainStatusAndLogIt("Processing Case #{case_index+1}/#{case_directories.size}")
			begin
				# Open the case
				pd.logMessage("\tOpening Case: #{case_directory}")
				nuix_case = $utilities.getCaseFactory.open(case_directory,{:migrate=>allow_migration})
				pd.logMessage("\tCase opened")

				case_name = nuix_case.getName
				case_guid = nuix_case.getGuid

				# Create output sub directory
				output_sub_directory = File.join(output_directory,time_stamp,"#{case_name}-#{case_guid}").gsub(/\//,"\\")
				pd.logMessage("\tCreating output directory: #{output_sub_directory}")
				java.io.File.new(output_sub_directory).mkdirs

				# Setup output
				file_list_base_name = "#{output_sub_directory}\\confirmed-files"
				missing_files_path = "#{output_sub_directory}\\missing_files.txt"

				output_text_file_writer = nil
				output_xml_file_writer = nil
				xml_file_list_fragment = nil
				xml_file_list_fragment_count = 0
				xml_fragments = []

				if create_file_list_as_text
					output_text_file_writer = RollingFileWriter.new(file_list_base_name,entry_limit)
					output_text_file_writer.when_message_logged do |message|
						pd.logMessage("\t"+message)
					end
				else
					output_xml_file_writer = RollingXmlFileWriter.new(file_list_base_name,entry_limit)
					output_xml_file_writer.when_message_logged do |message|
						pd.logMessage("\t"+message)
					end
				end

				# Find the items
				pd.logMessage("\tScope Query: #{scope_query}")
				pd.setSubStatusAndLogIt("\tLocating items...")
				items = nuix_case.searchUnsorted(scope_query)
				pd.logMessage("\tLocated #{items.size} items")

				missing_files = []

				# Do we actually have items to work with here?
				if items.size < 1
					pd.logMessage("\tCase contains no responsive items, moving on to next case...")
					next
				else
					pd.setSubProgress(0,items.size)
					items.each_with_index do |item,item_index|
						if (Time.now - last_progress) > 0.5 || (item_index + 1) == items.size
							pd.setSubStatus("Recording item #{item_index+1}/#{items.size}")
							pd.setSubProgress(item_index+1)
							last_progress = Time.now
						end

						physical_path = Helpers.get_physical_path(item)
						
						# If we couldn't obtain a on disk path, skip this item
						if physical_path.nil?
							begin
								missing_files << item.getUri
							rescue Exception => exc
								missing_files << exc.message
							end
							next
						end

						j_physical_file = java.io.File.new(physical_path)

						# If this item's physical path is a directory, skip it
						if j_physical_file.isDirectory
							missing_files << physical_path
							next
						end

						# If this item doesn't actually exist, skip it
						if verify_file_existence && !j_physical_file.exists
							missing_files << physical_path
							next
						end

						# Collect up relevant data about this item
						item_data = {}
						item_data["FilePath"] = physical_path
						if verify_creation_date
							item_data["CreationDate"] = formatter.print(item.getProperties.get("File Created"))
						end
						if verify_modification_date
							item_data["ModificationDate"] = formatter.print(item.getProperties.get("File Modified"))
						end
						if verify_access_date
							item_data["LastAccessDate"] = formatter.print(item.getProperties.get("File Accessed"))
						end
						if verify_size
							item_data["FileSize"] = item.getFileSize
						end
						if verify_md5_hash
							item_data["MD5Hash"] = item.getDigests.getMd5
						end

						# Record item data either to a text file or as XML nodes
						if create_file_list_as_text
							# Logic to populate text file list
							entry_pieces = []
							item_data.each do |key,value|
								entry_pieces << "#{key}=#{value}"
							end
							output_text_file_writer.puts(entry_pieces.join("\n"))
						else
							# Xml fragment logic here
							output_xml_file_writer.add_file_entry(item_data)
						end
					end

					# Class which renders the final job file based on all the settings
					job = CollectorJob.new(job_template_file)
					job.output_log_directory = output_sub_directory
					job.overwrite_count = overwrite_count
					job.scramble_creation_date = scramble_creation_date
					job.scramble_modification_date = scramble_modification_date
					job.scramble_access_date = scramble_access_date
					job.scramble_name = scramble_name
					job.delete_folders = delete_folders
					job.username = username
					job.domain = domain
					job.password = password
					job.investigator = nuix_case.getInvestigator
					job.case_name = nuix_case.getName
					job.do_delete = remediation_settings[:delete]
					job.do_copy = remediation_settings[:copy]
					job.overwrite_while_copying = overwrite_while_copying
					job.extract_path_directory = extract_path_directory
					job.add_attribute_r = add_attribute_r
					job.add_attribute_a = add_attribute_a
					job.add_attribute_s = add_attribute_s
					job.add_attribute_h = add_attribute_h
					job.remove_attribute_r = remove_attribute_r
					job.remove_attribute_a = remove_attribute_a
					job.remove_attribute_s = remove_attribute_s
					job.remove_attribute_h = remove_attribute_h
					job.compress_files = compress_files
					job.compression_level = compression_level
					job.encrypt_files = encrypt_files
					job.encryption_password = encryption_password
					job.change_file_owner = change_file_owner
					job.new_file_owner = new_file_owner

					# Determine where we are saving the job file
					output_job_file_path = File.join(output_sub_directory,"collector-job-file.xml")

					pd.setSubStatus("Building XML Job File")
					pd.logMessage("\tBuilding XML job file: #{output_job_file_path}")
					if create_file_list_as_text
						# Close any currently open text file
						output_text_file_writer.close
						# Save out a job file
						job.save_text_file_list_based(output_job_file_path,output_text_file_writer.created_files)
					else
						# Finalize last XML file
						output_xml_file_writer.close
						# Save out a job file
						job.save_xml_file_list_based(output_job_file_path,output_xml_file_writer.created_files)
					end

					# Write out missing files listing if needed
					pd.logMessage("\tMissing Files: #{missing_files.size}")
					if missing_files.size > 0
						pd.setSubStatus("Building Missing Files List")
						pd.logMessage("\tBuilding missing files list: #{missing_files_path}")
						File.open(missing_files_path, "w:utf-8") do |file|
							missing_files.each do |missing_file|
								file.puts(missing_file)
							end
						end
					end

					# Perform job if asked for
					if run_collector_job
						pd.setSubStatus("Performing Job with Collector")
						pd.logMessage("\tPerforming Job with collector...")
						command = "\"#{collector_exe}\" \"#{output_sub_directory}\\collector-job-file.xml\" 2"
						pd.logMessage("\tCollector command: #{command}")
						pd.logMessage("\tRunning command...")
						run(command,true,File.dirname(collector_exe))
					end
				end
			rescue => exc
				pd.logMessage("Error while processing case: #{exc.message}")
				pd.logMessage(exc.backtrace.join("\n"))
			ensure
				if !nuix_case.nil?
					nuix_case.close
				end
			end
		end

		pd.setCompleted
	end
end