path = File.dirname(File.absolute_path(__FILE__) )
Dir.glob(path + '/tools/*').delete_if{|file| File.directory?(file) }.each{|file| require file}
module Tools

end
