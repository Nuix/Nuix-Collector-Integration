# Class which handles rolling into new files based on a maximum/current entry count
require 'rexml/document'

class RollingXmlFileWriter
	attr_accessor :counter
	attr_accessor :entry_count
	attr_accessor :created_files

	def initialize(base_path,entry_max)
		@base_path = base_path
		@entry_max = entry_max
		@counter = 0
		@entry_count = 0
		@created_files = []

		@current_document = REXML::Document.new("<Files></Files>")
		@current_document.context[:attribute_quote] = :quote
	end

	def when_message_logged(&block)
		@message_logged_callback = block
	end

	def log_message(message)
		if !@message_logged_callback.nil?
			@message_logged_callback.call(message)
		end
	end

	def add_file_entry(data)
		element = @current_document.root.add_element("File")
		data.each do |key,value|
			element.attributes[key] = value
		end
		@entry_count += 1
		if @entry_count >= @entry_max
			close
			@current_document = REXML::Document.new("<Files></Files>")
			@current_document.context[:attribute_quote] = :quote
		end
	end

	def close
		@counter += 1
		if counter == 1
			@current_file_path = "#{@base_path}.xml"
		else
			index = @counter.to_s.rjust(4,"0")
			@current_file_path = "#{@base_path}_#{index}.xml"
		end

		fragment_string = ""
		@current_document.write(fragment_string,2)
		log_message("Saving file: #{File.basename(@current_file_path)}")
		File.open(@current_file_path, "w:utf-8") do |file|
			file.puts(fragment_string)
		end
		@created_files << @current_file_path
		@entry_count = 0
	end
end