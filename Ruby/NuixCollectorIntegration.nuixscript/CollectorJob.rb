require 'rexml/document'

class CollectorJob
	attr_accessor :output_log_directory
	attr_accessor :overwrite_count
	attr_accessor :scramble_creation_date
	attr_accessor :scramble_modification_date
	attr_accessor :scramble_access_date
	attr_accessor :scramble_name
	attr_accessor :delete_folders
	attr_accessor :username
	attr_accessor :domain
	attr_accessor :password
	attr_accessor :investigator
	attr_accessor :case_name

	attr_accessor :do_delete
	attr_accessor :do_copy
	attr_accessor :overwrite_while_copying
	attr_accessor :copy_mode
	attr_accessor :extract_path_directory

	# Attributes added/removed during remediation
	attr_accessor :add_attribute_r
	attr_accessor :add_attribute_a
	attr_accessor :add_attribute_s
	attr_accessor :add_attribute_h
	attr_accessor :remove_attribute_r
	attr_accessor :remove_attribute_a
	attr_accessor :remove_attribute_s
	attr_accessor :remove_attribute_h

	# Compression/encryption settings
	attr_accessor :compress_files
	attr_accessor :compression_level
	attr_accessor :encrypt_files
	attr_accessor :encryption_password

	# File ownership
	attr_accessor :change_file_owner
	attr_accessor :new_file_owner

	def initialize(template_file_path)
		@template_source = File.read(template_file_path,mode: "rb:bom|utf-8")

		@do_delete = false
		@do_copy = false
		@overwrite_while_copying = false
		@copy_mode = true
		@extract_path_directory = ""

		@add_attribute_r = false
		@add_attribute_a = false
		@add_attribute_s = false
		@add_attribute_h = false

		@remove_attribute_r = false
		@remove_attribute_a = false
		@remove_attribute_s = false
		@remove_attribute_h = false		

		@compress_files = false
		@compression_level = 6
		@encrypt_files = false
		@encryption_password = ""

		@change_file_owner = false
		@new_file_owner = ""
	end

	def render(base_file_list_name,list_element_name,list_file_paths)
		@investigator ||= ""
		@case_name ||= ""
		scramble_creation_date_value = @scramble_creation_date ? "yes" : "no"
		scramble_modification_date_value = @scramble_creation_date ? "yes" : "no"
		scramble_access_date_value = @scramble_creation_date ? "yes" : "no"
		scramble_name_value = @scramble_creation_date ? "yes" : "no"
		delete_folders_value = @delete_folders ? "yes" : "no"
		file_listing = build_filelisting(list_element_name,list_file_paths)

		do_delete_value = @do_delete ? "yes" : "no"
		do_extract_value = @do_copy ? "yes" : "no"

		return @template_source.encode("utf-8")
			.gsub("~BASEFILELISTNAME~".encode("utf-8"),base_file_list_name.encode("utf-8"))
			.gsub("~OUTPUTLOGDIRECTORY~".encode("utf-8"),@output_log_directory.gsub("\\","\\\\\\").encode("utf-8"))
			.gsub("~INVESTIGATOR~".encode("utf-8"),@investigator.gsub("\\","\\\\\\").encode("utf-8"))
			.gsub("~CASENAME~".encode("utf-8"),@case_name.gsub("\\","\\\\\\").encode("utf-8"))
			.gsub("~OVERWRITECOUNT~".encode("utf-8"),@overwrite_count.to_i.to_s.encode("utf-8"))
			.gsub("~SCRAMBLECREATIONDATE~".encode("utf-8"),scramble_creation_date_value.encode("utf-8"))
			.gsub("~SCRAMBLEMODIFICATIONDATE~".encode("utf-8"),scramble_modification_date_value.encode("utf-8"))
			.gsub("~SCRAMBLEACCESSDATE~".encode("utf-8"),scramble_access_date_value.encode("utf-8"))
			.gsub("~SCRAMBLENAME~".encode("utf-8"),scramble_name_value.encode("utf-8"))
			.gsub("~DELETEFOLDERS~".encode("utf-8"),delete_folders_value.encode("utf-8"))
			.gsub("~USERNAME~".encode("utf-8"),@username.to_s.gsub("\\","\\\\\\").encode("utf-8"))
			.gsub("~DOMAIN~".encode("utf-8"),@domain.to_s.gsub("\\","\\\\\\").encode("utf-8"))
			.gsub("~PASSWORD~".encode("utf-8"),@password.to_s.gsub("\\","\\\\\\").encode("utf-8"))
			.gsub("~FILELIST~".encode("utf-8"),file_listing)
			.gsub("~DO_DELETE~".encode("utf-8"),do_delete_value)
			.gsub("~DO_EXTRACT~".encode("utf-8"),do_extract_value)
			.gsub("~EXTRACT_PATH_NODE~".encode("utf-8"),build_extract_path_node)
			.gsub("~REMEDIATION_NODE~".encode("utf-8"),build_remediation_node)
	end

	def is_delete_only?
		return !(@do_copy || (!@do_copy && !@do_delete))
	end

	def build_extract_path_node
		#<ExtractPath OverWrite="no" CopyMode="yes">%TESTDIRECTORY%\Target</ExtractPath>
		root = REXML::Document.new
		root.context[:attribute_quote] = :quote
		extract_path_node = root.add_element("ExtractPath")
		extract_path_node.attributes["OverWrite"] = @overwrite_while_copying ? "yes" : "no"
		extract_path_node.attributes["CopyMode"] = @copy_mode ? "yes" : "no"
		extract_path_node.text = @extract_path_directory
		return extract_path_node.to_s.encode("utf-8")
	end

	def build_remediation_node
    root = REXML::Document.new
    root.context[:attribute_quote] = :quote
    remediation_node = root.add_element("Remediation")
    remediation_node.attributes["Enable"] = is_delete_only? ? "no" : "yes"
      
		if !is_delete_only?
  		# <Remediation Enable="yes">
  		# 	<FileAttributes>+r+h</FileAttributes>
  		# 	<Compression Level="6">zip</Compression>
  		# 	<Encryption Password="password">zip</Encryption>
  		# 	<FileOwner>Domain\User</FileOwner>
  		# </Remediation>
  
  		attributes = []
  		attributes << "+r" if @add_attribute_r
  		attributes << "+a" if @add_attribute_a
  		attributes << "+s" if @add_attribute_s
  		attributes << "+h" if @add_attribute_h
  		attributes << "-r" if @remove_attribute_r
  		attributes << "-a" if @remove_attribute_a
  		attributes << "-s" if @remove_attribute_s
  		attributes << "-h" if @remove_attribute_h
  		attributes_string = attributes.join("")
  
  		attributes_node = remediation_node.add_element("FileAttributes")
  		attributes_node.text = attributes_string
  
  		# Only produce something if we are compressing and the remediation choice
  		# is not pure deletion
  		if @compress_files && !is_delete_only?
  			compression_node = remediation_node.add_element("Compression")
  			compression_node.attributes["Level"] = @compression_level.to_i.to_s
  			compression_node.text = "zip"
  
  			# Are we also encrypting?
  			if @encrypt_files
  				encryption_node = remediation_node.add_element("Encryption")
  				encryption_node.attributes["Password"] = @encryption_password
  				encryption_node.text = "zip"
  			end
  		end
  		
  		if @change_file_owner && !is_delete_only?
  			file_owner_node = remediation_node.add_element("FileOwner")
  			file_owner_node.text = @new_file_owner
  		end
		end
		
    formatter = REXML::Formatters::Pretty.new
    formatter.compact = true
    return formatter.write(remediation_node,"").encode("utf-8")
	end

	def build_filelisting(list_element_name,list_file_paths)
		converted = []
		list_file_paths.each do |file_path|
			root = REXML::Document.new
			root.context[:attribute_quote] = :quote
			node = root.add_element(list_element_name)
			node.text = file_path.gsub("\\","\\\\\\")
			node.attributes["LoginUser"] = @username || ""
			node.attributes["LoginDomain"] = @domain || ""
			node.attributes["Password"] = @password || ""
			converted << node.to_s.encode("utf-8")
		end
		return converted.join("\n".encode("utf-8"))
	end

	def save_text_file_list_based(path,list_file_paths)
		base_file_list_name = "FileList {DateTime}".encode("utf-8")
		rendered = render(base_file_list_name,"ExtendedFileList",list_file_paths)
		File.open(path, "wb:utf-8") do |file|
			file.write("\xEF\xBB\xBF")
			file.write(rendered)
		end
	end

	def save_xml_file_list_based(path,list_file_paths)
		base_file_list_name = "XML FileList {DateTime}".encode("utf-8")
		rendered = render(base_file_list_name,"XMLFileList",list_file_paths)
		File.open(path, "wb:utf-8") do |file|
			# In Nuix 6.2 (and maybe some version so after that) we must call
			# force encoding or we will get an encoding conflict error about
			# ASCII8-BIT cant be converted into UTF-8
			file.write("\xEF\xBB\xBF".force_encoding("UTF-8"))
			file.write(rendered)
		end
	end
end