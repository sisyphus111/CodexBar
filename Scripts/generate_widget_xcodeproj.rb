#!/usr/bin/env ruby
# frozen_string_literal: true

require "fileutils"
require "xcodeproj"

root = File.expand_path("..", __dir__)
project_path = File.join(root, "CodexBarWidget.xcodeproj")
FileUtils.rm_rf(project_path)

project = Xcodeproj::Project.new(project_path)
target = project.new_target(:app_extension, "CodexBarWidget", :osx, "14.0")

group = project.main_group.new_group("CodexBarWidget", "Sources/CodexBarWidget")
source_paths = Dir.glob(File.join(root, "Sources/CodexBarWidget/*.swift")).sort
source_refs = source_paths.map { |path| group.new_file(File.basename(path)) }
target.add_file_references(source_refs)

package = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
package.relative_path = "."
project.root_object.package_references << package

core_product = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
core_product.package = package
core_product.product_name = "CodexBarCore"
target.package_product_dependencies << core_product

core_build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
core_build_file.product_ref = core_product
target.frameworks_build_phase.files << core_build_file

target.build_configurations.each do |config|
  settings = config.build_settings
  settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  settings["CODE_SIGNING_ALLOWED"] = "NO"
  settings["CODE_SIGN_STYLE"] = "Manual"
  settings["ENABLE_APP_SANDBOX"] = "YES"
  settings["GENERATE_INFOPLIST_FILE"] = "NO"
  settings["INFOPLIST_FILE"] = "Sources/CodexBarWidget/Info.plist"
  settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/../Frameworks"
  settings["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.steipete.codexbar.widget"
  settings["PRODUCT_NAME"] = "CodexBarWidget"
  settings["SDKROOT"] = "macosx"
  settings["SWIFT_VERSION"] = "6.0"
  settings["WK_APP_BUNDLE_IDENTIFIER"] = "com.steipete.codexbar"
end

project.save

resolved_packages_dir = File.join(project_path, "project.xcworkspace/xcshareddata/swiftpm")
FileUtils.mkdir_p(resolved_packages_dir)
FileUtils.cp(
  File.join(root, "Package.resolved"),
  File.join(resolved_packages_dir, "Package.resolved"),
)
