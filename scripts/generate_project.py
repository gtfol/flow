#!/usr/bin/env python3
"""Generate a complete dependency-free Xcode project using only the standard library."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Flow.xcodeproj"
objects = {}


def ident(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()


def add(object_name, isa, **fields):
    key = ident(object_name)
    objects[key] = {"isa": isa, **fields}
    return key


def encode(value, level=0):
    if isinstance(value, dict):
        return "{\n" + "".join("\t" * (level + 1) + f"{key} = {encode(val, level + 1)};\n" for key, val in value.items()) + "\t" * level + "}"
    if isinstance(value, list):
        return "(" + ", ".join(encode(item, level) for item in value) + ")"
    return json.dumps(str(value))


def configs(name, settings):
    ids = []
    for configuration in ["Debug", "Release"]:
        values = dict(settings)
        values["SWIFT_OPTIMIZATION_LEVEL"] = "-Onone" if configuration == "Debug" else "-O"
        values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG" if configuration == "Debug" else ""
        values["DEBUG_INFORMATION_FORMAT"] = "dwarf" if configuration == "Debug" else "dwarf-with-dsym"
        values["ENABLE_TESTABILITY"] = "YES" if configuration == "Debug" else "NO"
        ids.append(add(name + configuration, "XCBuildConfiguration", name=configuration, buildSettings=values))
    return add(name + "configlist", "XCConfigurationList", buildConfigurations=ids,
               defaultConfigurationIsVisible=0, defaultConfigurationName="Release")


def reference(path):
    types = {".swift": "sourcecode.swift", ".json": "text.json", ".wav": "audio.wav", ".mp3": "audio.mp3",
             ".xcprivacy": "text.xml", ".xcassets": "folder.assetcatalog"}
    return add(str(path) + "ref", "PBXFileReference", path=str(path),
               lastKnownFileType=types.get(path.suffix, "text"), sourceTree="<group>")


sources = [path.relative_to(ROOT) for path in sorted((ROOT / "Flow").rglob("*.swift"))]
resources = [Path("Flow/Resources") / name for name in ["sessions.json", "ambient.wav", "inhale.wav", "exhale.wav", "introduction.mp3", "PrivacyInfo.xcprivacy", "Assets.xcassets"]]
refs = {str(path): reference(path) for path in sources + resources}
source_builds = [add(str(path) + "build", "PBXBuildFile", fileRef=refs[str(path)]) for path in sources]
resource_builds = [add(str(path) + "build", "PBXBuildFile", fileRef=refs[str(path)]) for path in resources]
app = add("product", "PBXFileReference", explicitFileType="wrapper.application", path="flow.app", sourceTree="BUILT_PRODUCTS_DIR")
products = add("products", "PBXGroup", children=[app], name="Products", sourceTree="<group>")
group = add("group", "PBXGroup", children=list(refs.values()) + [products], sourceTree="<group>")
source_phase = add("sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=source_builds, runOnlyForDeploymentPostprocessing=0)
resource_phase = add("resources", "PBXResourcesBuildPhase", buildActionMask=2147483647, files=resource_builds, runOnlyForDeploymentPostprocessing=0)
framework_phase = add("frameworks", "PBXFrameworksBuildPhase", buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)
project_config = configs("project", {"IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES"})
target_config = configs("target", {
    "PRODUCT_NAME": "flow", "PRODUCT_MODULE_NAME": "Flow", "PRODUCT_BUNDLE_IDENTIFIER": "dev.gtfol.flow",
    "GENERATE_INFOPLIST_FILE": "YES", "INFOPLIST_KEY_CFBundleDisplayName": "flow",
    "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO",
    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.healthcare-fitness",
    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES", "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
    "INFOPLIST_KEY_UIUserInterfaceStyle": "Dark", "TARGETED_DEVICE_FAMILY": "1",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "J59ZSG67SJ",
    "CURRENT_PROJECT_VERSION": "3", "MARKETING_VERSION": "0.1.0",
    "SWIFT_EMIT_LOC_STRINGS": "YES", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"]
})
target = add("target", "PBXNativeTarget", name="Flow", productName="flow", productReference=app,
             productType="com.apple.product-type.application", buildConfigurationList=target_config,
             buildPhases=[source_phase, framework_phase, resource_phase], buildRules=[], dependencies=[])
test_sources = [path.relative_to(ROOT) for folder in ["FlowTests", "FlowNativeTests"]
                for path in sorted((ROOT / folder).glob("*.swift"))]
test_refs = [reference(path) for path in test_sources]
objects[group]["children"].extend(test_refs)
test_builds = [add(str(path) + "build", "PBXBuildFile", fileRef=ref) for path, ref in zip(test_sources, test_refs)]
test_phase = add("test-sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=test_builds, runOnlyForDeploymentPostprocessing=0)
test_product = add("test-product", "PBXFileReference", explicitFileType="wrapper.cfbundle", path="FlowTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
objects[products]["children"].append(test_product)
test_config = configs("tests", {
    "PRODUCT_NAME": "FlowTests", "PRODUCT_BUNDLE_IDENTIFIER": "dev.gtfol.flow.tests",
    "GENERATE_INFOPLIST_FILE": "YES", "TARGETED_DEVICE_FAMILY": "1",
    "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/flow.app/flow", "BUNDLE_LOADER": "$(TEST_HOST)",
    "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "J59ZSG67SJ", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]
})
proxy = add("test-proxy", "PBXContainerItemProxy", containerPortal=ident("project"), proxyType=1, remoteGlobalIDString=target, remoteInfo="Flow")
dependency = add("test-dependency", "PBXTargetDependency", target=target, targetProxy=proxy)
test_target = add("test-target", "PBXNativeTarget", name="FlowTests", productName="FlowTests",
                  productReference=test_product, productType="com.apple.product-type.bundle.unit-test",
                  buildConfigurationList=test_config, buildPhases=[test_phase], buildRules=[], dependencies=[dependency])
ui_sources = [path.relative_to(ROOT) for path in sorted((ROOT / "FlowUITests").glob("*.swift"))]
ui_refs = [reference(path) for path in ui_sources]
objects[group]["children"].extend(ui_refs)
ui_builds = [add(str(path) + "build", "PBXBuildFile", fileRef=ref) for path, ref in zip(ui_sources, ui_refs)]
ui_phase = add("ui-sources", "PBXSourcesBuildPhase", buildActionMask=2147483647, files=ui_builds, runOnlyForDeploymentPostprocessing=0)
ui_product = add("ui-product", "PBXFileReference", explicitFileType="wrapper.cfbundle", path="FlowUITests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
objects[products]["children"].append(ui_product)
ui_config = configs("ui-tests", {
    "PRODUCT_NAME": "FlowUITests", "PRODUCT_BUNDLE_IDENTIFIER": "dev.gtfol.flow.uitests",
    "GENERATE_INFOPLIST_FILE": "YES", "TARGETED_DEVICE_FAMILY": "1", "TEST_TARGET_NAME": "Flow",
    "CODE_SIGN_STYLE": "Automatic", "DEVELOPMENT_TEAM": "J59ZSG67SJ",
    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]
})
ui_dependency = add("ui-dependency", "PBXTargetDependency", target=target, targetProxy=proxy)
ui_target = add("ui-target", "PBXNativeTarget", name="FlowUITests", productName="FlowUITests",
                productReference=ui_product, productType="com.apple.product-type.bundle.ui-testing",
                buildConfigurationList=ui_config, buildPhases=[ui_phase], buildRules=[], dependencies=[ui_dependency])
project = add("project", "PBXProject", attributes={"LastUpgradeCheck": "2660"}, buildConfigurationList=project_config,
              compatibilityVersion="Xcode 14.0", developmentRegion="en", knownRegions=["en", "Base"],
              mainGroup=group, productRefGroup=products, projectDirPath="", projectRoot="", targets=[target, test_target, ui_target])
PROJECT.mkdir(exist_ok=True)
(PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode({"archiveVersion": 1, "classes": {}, "objectVersion": 56, "objects": objects, "rootObject": project}) + "\n")
scheme_dir = PROJECT / "xcshareddata" / "xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="flow.app" BlueprintName="Flow" ReferencedContainer="container:Flow.xcodeproj"/>'
test_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="FlowTests.xctest" BlueprintName="FlowTests" ReferencedContainer="container:Flow.xcodeproj"/>'
ui_ref = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_target}" BuildableName="FlowUITests.xctest" BlueprintName="FlowUITests" ReferencedContainer="container:Flow.xcodeproj"/>'
(scheme_dir / "Flow.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2660" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference><TestableReference skipped="NO">{ui_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''')
print(PROJECT)
