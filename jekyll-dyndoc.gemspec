
require 'rubygems/package_task'

pkg_name='jekyll-dyndoc'
pkg_version='0.0.1'

pkg_files=FileList[
    'lib/**/*.rb'
]

spec = Gem::Specification.new do |s|
    s.platform = Gem::Platform::RUBY
    s.summary = "jekyll dyndoc"
    s.name = pkg_name
    s.version = pkg_version
    s.licenses = ['MIT', 'GPL-2']
    s.requirements << 'none'
    s.add_runtime_dependency 'dyndoc-ruby','>= 0.6.0'
    s.require_path = 'lib'
    s.files = pkg_files.to_a
    s.description = <<-EOF
  Dyndoc jekyll plugin.
  EOF
    s.author = "CQLS"
    s.email= "rdrouilh@gmail.com"
    s.homepage = "http://cqls.upmf-grenoble.fr"
    s.rubyforge_project = nil
end
