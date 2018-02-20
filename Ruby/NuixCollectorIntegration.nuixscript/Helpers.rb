# Convenience methods
class Helpers
	def self.get_physical_path(item)
		# Some items have odd URI values containing a : which causes a Java NIO library
		# to throw an exception so we should be ready for this
		begin
			uri = item.getUri
		rescue Exception => exc
			puts "Error fetching URI for item => GUID: #{item.getGuid} NAME: #{item.getLocalisedName}"
			return nil
		end

		if uri.nil?
			puts "Item has no URI value => GUID: #{item.getGuid} NAME: #{item.getLocalisedName}"
			return nil
		else
			strPath = nil
			begin
				# Create a URI object to get the path - no escapes
				uriOutput = java.net.URI.new(uri)
				strOutput = uriOutput.getPath()
				
				# check for a host.  If this is a UNC path, the host will not
				# be included in the path
				strHost = uriOutput.getHost()
				if strHost.nil?
					# remove the first character - this is an unneeded /
					strPath = strOutput[1..-1]
				else
					strPath = "\\\\"
					strPath += strHost
					strPath += strOutput
				end
				
				# convert forward slashes to back slashes
				strPath.gsub!('/','\\')
			rescue Exception => ex
				puts "Error parsing URI '#{exc.message}' => GUID: #{item.getGuid} NAME: #{item.getLocalisedName}"
				return nil
			end
			return strPath
		end
	end
end