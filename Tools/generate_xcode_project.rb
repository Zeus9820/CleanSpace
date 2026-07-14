#!/usr/bin/env ruby
# frozen_string_literal: true

require "xcodeproj"

ROOT = File.expand_path("..", __dir__)
PROJECT_PATH = File.join(ROOT, "CleanSpace.xcodeproj")
abort "#{PROJECT_PATH} already exists" if File.exist?(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes["LastSwiftUpdateCheck"] = "2660"
project.root_object.attributes["LastUpgradeCheck"] = "2660"

sources_group = project.main_group.new_group("Sources", "Sources")
tests_group = project.main_group.new_group("Tests", "Tests")
config_group = project.main_group.new_group("Configurations", "Configurations")

def references(group, root, pattern)
  Dir.glob(File.join(root, pattern)).sort.map do |absolute_path|
    group.new_file(absolute_path.delete_prefix("#{group.real_path}/"))
  end
end

core_group = sources_group.new_group("CleanSpaceCore", "CleanSpaceCore")
direct_group = sources_group.new_group("CleanSpaceDirect", "CleanSpaceDirect")
store_group = sources_group.new_group("CleanSpaceStore", "CleanSpaceStore")
core_refs = references(core_group, File.join(ROOT, "Sources/CleanSpaceCore"), "**/*.swift")
direct_refs = references(direct_group, File.join(ROOT, "Sources/CleanSpaceDirect"), "*.swift")
store_refs = references(store_group, File.join(ROOT, "Sources/CleanSpaceStore"), "*.swift")
direct_privacy = direct_group.new_file("Resources/PrivacyInfo.xcprivacy")
store_privacy = store_group.new_file("Resources/PrivacyInfo.xcprivacy")
test_refs = references(tests_group, File.join(ROOT, "Tests"), "**/*.swift")

shared_config = config_group.new_file("Shared.xcconfig")
direct_entitlements = config_group.new_file("CleanSpaceDirect.entitlements")
store_entitlements = config_group.new_file("CleanSpaceStore.entitlements")

core = project.new_target(:static_library, "CleanSpaceCore", :osx, "26.0")
direct = project.new_target(:application, "CleanSpaceDirect", :osx, "26.0")
store = project.new_target(:application, "CleanSpaceStore", :osx, "26.0")
tests = project.new_target(:unit_test_bundle, "CleanSpaceCoreTests", :osx, "26.0")

core.add_file_references(core_refs)
direct.add_file_references(direct_refs)
store.add_file_references(store_refs)
tests.add_file_references(test_refs)
direct.resources_build_phase.add_file_reference(direct_privacy)
store.resources_build_phase.add_file_reference(store_privacy)

[direct, store, tests].each do |target|
  target.add_dependency(core)
  target.frameworks_build_phase.add_file_reference(core.product_reference)
end
tests.add_dependency(direct)

project.build_configurations.each { |configuration| configuration.base_configuration_reference = shared_config }
[core, direct, store, tests].each do |target|
  target.build_configurations.each { |configuration| configuration.base_configuration_reference = shared_config }
end

core.build_configurations.each do |configuration|
  configuration.build_settings.merge!(
    "DEFINES_MODULE" => "YES",
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.cleanspace.core",
    "PRODUCT_MODULE_NAME" => "CleanSpaceCore",
    "SKIP_INSTALL" => "YES"
  )
end

{
  direct => {
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.cleanspace.direct",
    "PRODUCT_NAME" => "CleanSpace",
    "CODE_SIGN_ENTITLEMENTS" => "Configurations/CleanSpaceDirect.entitlements",
    "INFOPLIST_KEY_CFBundleDisplayName" => "CleanSpace Direct"
  },
  store => {
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.cleanspace.store",
    "PRODUCT_NAME" => "CleanSpace Store",
    "CODE_SIGN_ENTITLEMENTS" => "Configurations/CleanSpaceStore.entitlements",
    "INFOPLIST_KEY_CFBundleDisplayName" => "CleanSpace"
  }
}.each do |target, settings|
  target.build_configurations.each do |configuration|
    configuration.build_settings.merge!(settings.merge(
      "GENERATE_INFOPLIST_FILE" => "YES",
      "INFOPLIST_KEY_LSApplicationCategoryType" => "public.app-category.utilities",
      "INFOPLIST_KEY_NSHumanReadableCopyright" => "Copyright © 2026",
      "MARKETING_VERSION" => "0.1.0",
      "CURRENT_PROJECT_VERSION" => "1"
    ))
  end
end

direct.build_configurations.find { |configuration| configuration.name == "Release" }
  .build_settings["CODE_SIGN_IDENTITY"] = "Developer ID Application"
store.build_configurations.find { |configuration| configuration.name == "Release" }
  .build_settings["CODE_SIGN_IDENTITY"] = "Apple Distribution"

tests.build_configurations.each do |configuration|
  configuration.build_settings.merge!(
    "GENERATE_INFOPLIST_FILE" => "YES",
    "PRODUCT_BUNDLE_IDENTIFIER" => "com.cleanspace.core-tests",
    "TEST_HOST" => "$(BUILT_PRODUCTS_DIR)/CleanSpace.app/Contents/MacOS/CleanSpace",
    "BUNDLE_LOADER" => "$(TEST_HOST)"
  )
end

project.save

{
  "CleanSpaceDirect" => direct,
  "CleanSpaceStore" => store
}.each do |name, launch_target|
  scheme = Xcodeproj::XCScheme.new
  scheme.add_build_target(core)
  scheme.add_build_target(launch_target)
  scheme.add_test_target(tests)
  scheme.set_launch_target(launch_target)
  scheme.save_as(PROJECT_PATH, name, true)
end

puts "Generated #{PROJECT_PATH}"
