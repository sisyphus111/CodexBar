#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"

root = File.expand_path("..", __dir__)
project_path = File.join(root, "CodexBarWidgetNative.xcodeproj")
project = Xcodeproj::Project.new(project_path)
target = project.new_target(:app_extension, "CodexBarWidget", :osx, "14.0")

group = project.main_group.new_group("CodexBarWidgetNative", "Sources/CodexBarWidgetNative")
source_ref = group.new_file("CodexBarWidgetNative.swift")
target.add_file_references([source_ref])

target.build_configurations.each do |config|
  settings = config.build_settings
  settings["PRODUCT_BUNDLE_IDENTIFIER"] = "com.steipete.codexbar.widget"
  settings["PRODUCT_NAME"] = "CodexBarWidget"
  settings["WK_APP_BUNDLE_IDENTIFIER"] = "com.steipete.codexbar"
  settings["INFOPLIST_FILE"] = "Sources/CodexBarWidgetNative/Info.plist"
  settings["SDKROOT"] = "macosx"
  settings["MACOSX_DEPLOYMENT_TARGET"] = "14.0"
  settings["SWIFT_VERSION"] = "6.0"
  settings["ENABLE_APP_SANDBOX"] = "YES"
  settings["APPLICATION_EXTENSION_API_ONLY"] = "YES"
  settings["CODE_SIGN_STYLE"] = "Manual"
  settings["CODE_SIGNING_ALLOWED"] = "NO"
  settings["GENERATE_INFOPLIST_FILE"] = "NO"
  settings["LD_RUNPATH_SEARCH_PATHS"] = "$(inherited) @executable_path/../Frameworks"
end

project.save
