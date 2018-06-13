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
	
	# Recursive method to return an item's closest physical ancestor
	# If the item is a physical file, returns item
	# If there is no physical ancestor, returns nil
	def self.find_physical_ancestor(item)
		if item.isPhysicalFile
			return item
		else
			parent = item.getParent
			if !parent.nil?
				find_physical_ancestor(parent)
			else
				return nil
			end
		end
	end
	
	# Iterates a collection of items and checks if the item has a URI
	# If not, searches for closest physical ancestor
	# Returns an array of unique items
	def self.get_physical_items(items)
		item_hash = Hash.new
		
		items.each do |item|
			if !item.getUri.nil?
				item_hash[item.getGuid] = item
			else
				physical_ancestor = find_physical_ancestor(item)
				if !physical_ancestor.nil?
					item_hash[physical_ancestor.getGuid] = physical_ancestor
				end
			end
		end
		
		return item_hash.values
	end
end