require 'rake/clean'
CLOBBER.include('bin', 'vendor', '.bundle', '*.gem')
CLEAN.include('build')

if File.expand_path(Rake.application.original_dir) != File.expand_path(Dir.pwd)
  raise StandardError, "Please launch rake from project root directory, where Rakefile is."
end


desc "Launch integration tests via docker"
task :integration_test => [:build_packages] do
	distro_filter = ENV["DISTRO_FILTER"] || '.*'
	Dir.entries('build-images').select {|entry| (File.directory? File.join('build-images', entry)) && !(entry =='.' || entry == '..') && (entry =~ /^#{distro_filter}$/) }.each { |distro_name|
		puts "Now testing packages for #{distro_name}"

		output_packages_dir = "#{Rake.application.original_dir}/build/#{distro_name}"
		sh "mkdir -p #{output_packages_dir}"

		test_dir = File.expand_path(File.join('build-images', distro_name, 'test'))
		image_name = "dorkbox-test-#{distro_name}"
		sh "docker build --pull -t #{image_name} #{test_dir}"

		sh "docker run --rm -v #{output_packages_dir}:/build:ro -v #{test_dir}:/test:ro "\
			"#{image_name} /test/test.sh"
		puts "Test done for #{distro_name}\n\n"
	}
end

desc "Use bundler to create binstubs. "
task :create_bundler_binstubs do
	bundler_exec = ENV["BUNDLER_EXEC"] || "bundler"
	ruby_exec = ENV["RUBY_EXEC"] || "ruby"
	production = ENV["PRODUCTION"] == 'yes' ? '--deployment --standalone' : ''

	sh "#{bundler_exec} install #{production} --path=./vendor/bundle --binstubs=./bin --shebang=#{ruby_exec}"
end

desc "Build packages via docker"
task :build_packages => [:clean] do
	distro_filter = ENV["DISTRO_FILTER"] || '.*'
  version_suffix = ENV["VERSION_SUFFIX"] ? "#{ENV['VERSION_SUFFIX']}" : 'build0'
	Dir.entries('build-images').select {|entry| (File.directory? File.join('build-images', entry)) && !(entry =='.' || entry == '..') && (entry =~ /^#{distro_filter}$/) }.each { |distro_name|
		puts "Now building packages for #{distro_name}"

		output_packages_dir = "#{Rake.application.original_dir}/build/#{distro_name}"
		sh "mkdir -p #{output_packages_dir}"

		build_image_dir = File.join('build-images', distro_name)
		image_name = "dorkbox-build-#{distro_name}"
		sh "docker build --pull -t #{image_name} #{build_image_dir}"

		sh "docker run --rm -v #{Rake.application.original_dir}:/application:ro -v #{output_packages_dir}:/build "\
			"-w /application #{image_name} /application/#{build_image_dir}/make-package.sh $(cat version.txt) #{version_suffix}"
		puts "Done\n\n"
	}

end
