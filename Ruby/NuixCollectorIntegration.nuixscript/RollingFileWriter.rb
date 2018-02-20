# Class which handles rolling into new files based on a maximum/current entry count
class RollingFileWriter
	attr_accessor :counter
	attr_accessor :entry_count
	attr_accessor :current_file_path
	attr_accessor :created_files

	def initialize(base_path,entry_max)
		@base_path = base_path
		@entry_max = entry_max
		@counter = 0
		@entry_count = 0
		@output_text_file = nil
		@created_files = []
	end

	def when_message_logged(&block)
		@message_logged_callback = block
	end

	def log_message(message)
		if !@message_logged_callback.nil?
			@message_logged_callback.call(message)
		end
	end

	def roll_file
		close
		@counter += 1
		if counter == 1
			@current_file_path = "#{@base_path}.txt"
		else
			index = @counter.to_s.rjust(4,"0")
			@current_file_path = "#{@base_path}_#{index}.txt"
		end

		@output_text_file = File.open(@current_file_path, "w:utf-8")
		@entry_count = 0
		# Track this file
		@created_files << @current_file_path
	end

	def close
		if !@output_text_file.nil?
			log_message("Saving file: #{@current_file_path}")
			@output_text_file.close
		end
	end

	def puts(string)
		if @current_file_path.nil?
			roll_file
		end
		@output_text_file.puts(string)
		@entry_count += 1
		if @entry_count >= @entry_max
			roll_file
		end
	end
end