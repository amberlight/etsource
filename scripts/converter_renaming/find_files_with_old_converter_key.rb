# This script finds all references to the old_keys as defined in the mentioned CSV file on the ETsource and ETengine.
# When references on the engine are found, these have to be changed by hand.
# References on ETsource can be updated automatically with the scripts named "change_files_with_old_converter_key".

require 'rubygems'
require 'CSV'
require 'fileutils'

CSV_WITH_REPLACEMENTS = "new_converter_keys.csv"
PATH_OF_REPOSITORIES = "/Users/WvL/Documents/github/"

#First define what we want to replace with what
replacements = {}
CSV.foreach(CSV_WITH_REPLACEMENTS) do |row|
  #this is how the columns of the CSV are ordered
  id, old_key, new_key = row
  replacements[old_key] = new_key unless old_key == new_key
end

#Then we define which files we will be going through
files = Dir.glob(PATH_OF_REPOSITORIES + "etsource/**/*") - Dir.glob(PATH_OF_REPOSITORIES + "etsource/datasets/**/*") - Dir.glob(PATH_OF_REPOSITORIES + "etsource/scripts/**/*") - Dir.glob(PATH_OF_REPOSITORIES + "etsource/topology/**/*")

#clean up file list with hidden files (that start with .) or files that are actually directories
files.delete_if do |file_name| 
  file_name[0] == "." || File.directory?(file_name) || File.ftype(file_name) != "file"
end

puts "Looking through etsource"

for file in files
  next unless File.file?(file)
  content = File.read(file)
  replacements.each do |old_key, new_key|
    if content =~ /#{old_key}/ then
      File.open(file)
      puts "The script can change the old key in #{file} from #{old_key} to #{new_key}" if content.gsub(old_key, new_key)
    end
  end
end


# Do the same for dataset files 
datasetfiles = Dir.glob(PATH_OF_REPOSITORIES + "etsource/datasets/**/*") + Dir.glob(PATH_OF_REPOSITORIES + "etsource/topology/**/*")

#clean up file list with hidden files (that start with .) or files that are actually directories
datasetfiles.delete_if do |datasetfile_name| 
  datasetfile_name[0] == "." || File.directory?(datasetfile_name) || File.ftype(datasetfile_name) != "file"
end

puts "Looking through the dataset"

for datasetfile in datasetfiles
  datasetcontent = File.read(datasetfile)
  replacements.each do |old_key, new_key|
    if datasetcontent =~ /#{old_key}/ then
      File.open(datasetfile)
    puts "#{old_key} in #{datasetfile} will be changed by InputExcel" if datasetcontent.gsub(old_key, new_key)
    end
  end
end


# Do the same for the etengine files
enginefiles = Dir.glob(PATH_OF_REPOSITORIES + "etengine/**/*") - Dir.glob(PATH_OF_REPOSITORIES + "etengine/etsource_export/**/*") - Dir.glob(PATH_OF_REPOSITORIES + "etengine/log/**/*")- Dir.glob(PATH_OF_REPOSITORIES + "etengine/etengine_staging.sql") 

#clean up file list with hidden files (that start with .) or files that are actually directories
enginefiles.delete_if do |enginefile_name| 
  enginefile_name[0] == "." || File.directory?(enginefile_name) || File.ftype(enginefile_name) != "file"
end

 puts "Looking through Etengine"

# this part is required for the etengine because of some problems that arise regarding an "invalid byte sequence in UTF-8"
require 'iconv' unless String.method_defined?(:encode)
for enginefile in enginefiles
  next unless File.file?(enginefile)
  enginecontent = File.read(enginefile)
    if String.method_defined?(:encode)
      enginecontent.encode!('UTF-8', 'UTF-8', :invalid => :replace)
    else
      ic = Iconv.new('UTF-8', 'UTF-8//IGNORE')
      enginecontent = ic.iconv(enginecontent)
    end
  replacements.each do |old_key, new_key|
    if enginecontent =~ /#{old_key}/ then
      File.open(enginefile)
      puts "The old key #{old_key} still exists in the ETengine! Here: #{enginefile}! Check if this is not a problem!" if enginecontent.gsub(old_key, new_key)
    end
  end
end
