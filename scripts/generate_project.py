#!/usr/bin/env python3
"""Generate the committed Xcode project using only Python's standard library."""
import hashlib
import json
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, help='Generate a reviewable project elsewhere without replacing local Xcode settings.')
OUT = parser.parse_args().output or ROOT / 'ThoughtMosaic.xcodeproj'
objects = {}

def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def add(key_name, isa, **values):
    key = uid(key_name)
    objects[key] = dict(isa=isa, **values)
    return key

def file(path, kind):
    return add('file:' + path, 'PBXFileReference', lastKnownFileType=kind, path=path, sourceTree='SOURCE_ROOT')

def config_list(name, values):
    configs = []
    for mode in ['Debug', 'Release']:
        settings = dict(values)
        settings.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode == 'Debug' else '-O',
                        DEBUG_INFORMATION_FORMAT='dwarf' if mode == 'Debug' else 'dwarf-with-dsym')
        if mode == 'Debug': settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        configs.append(add(name + mode, 'XCBuildConfiguration', buildSettings=settings, name=mode))
    return add(name + 'configs', 'XCConfigurationList', buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName='Release')

project_id = uid('project')
targets = []
groups = []
products = []
names = ['ThoughtMosaic', 'ThoughtMosaicWidget', 'ThoughtMosaicShare', 'ThoughtMosaicUITests']
for name in names:
    source_paths = sorted((ROOT / name).glob('*.swift'))
    if name in ['ThoughtMosaic', 'ThoughtMosaicShare']:
        source_paths += sorted((ROOT / 'Sources/MosaicCore').glob('*.swift'))
    if name == 'ThoughtMosaicShare': source_paths += [ROOT / 'ThoughtMosaic/Theme.swift', ROOT / 'ThoughtMosaic/TagSheet.swift']
    refs, build = [], []
    for source in source_paths:
        path = str(source.relative_to(ROOT))
        ref = file(path, 'sourcecode.swift')
        if name != 'ThoughtMosaicShare' or path.startswith('ThoughtMosaicShare/'):
            refs.append(ref)
        build.append(add(name + ':' + path, 'PBXBuildFile', fileRef=ref))
    info = ROOT / name / 'Info.plist'
    if info.exists(): refs.append(file(str(info.relative_to(ROOT)), 'text.plist.xml'))
    entitlements = ROOT / name / (name + '.entitlements')
    if entitlements.exists(): refs.append(file(str(entitlements.relative_to(ROOT)), 'text.plist.entitlements'))
    resources = []
    for resource in sorted((ROOT / name).glob('*.xcstrings')):
        path = str(resource.relative_to(ROOT))
        ref = file(path, 'text.json.xcstrings')
        refs.append(ref)
        resources.append(add(name + ':' + path, 'PBXBuildFile', fileRef=ref))
    groups.append(add(name + 'group', 'PBXGroup', children=refs, name=name, sourceTree='<group>'))
    suffix = '.app' if name == 'ThoughtMosaic' else '.appex' if name in ['ThoughtMosaicWidget', 'ThoughtMosaicShare'] else '.xctest'
    product = add(name + 'product', 'PBXFileReference', explicitFileType={'app':'wrapper.application','appex':'wrapper.app-extension','xctest':'wrapper.cfbundle'}[suffix[1:]],
                  includeInIndex=0, path=name + suffix, sourceTree='BUILT_PRODUCTS_DIR')
    products.append(product)
    phases = [add(name + 'sources', 'PBXSourcesBuildPhase', buildActionMask=2147483647, files=build, runOnlyForDeploymentPostprocessing=0),
              add(name + 'frameworks', 'PBXFrameworksBuildPhase', buildActionMask=2147483647, files=[], runOnlyForDeploymentPostprocessing=0)]
    if resources:
        phases.append(add(name + 'resources', 'PBXResourcesBuildPhase', buildActionMask=2147483647, files=resources, runOnlyForDeploymentPostprocessing=0))
    dependencies = []
    if name == 'ThoughtMosaic':
        embeds = [add('embed-widget', 'PBXBuildFile', fileRef=uid('ThoughtMosaicWidgetproduct'), settings={'ATTRIBUTES':['RemoveHeadersOnCopy']}),
                  add('embed-share', 'PBXBuildFile', fileRef=uid('ThoughtMosaicShareproduct'), settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})]
        phases.append(add('embed-extensions', 'PBXCopyFilesBuildPhase', buildActionMask=2147483647, dstPath='', dstSubfolderSpec=13,
                          files=embeds, name='Embed App Extensions', runOnlyForDeploymentPostprocessing=0))
        dependency_names = ['ThoughtMosaicWidget', 'ThoughtMosaicShare']
    elif name.endswith('UITests'): dependency_names = ['ThoughtMosaic']
    else: dependency_names = []
    for dependency in dependency_names:
        # Preserve the existing widget/test object identifiers.
        key = name if dependency != 'ThoughtMosaicShare' else name + '-share'
        proxy = add(key + 'proxy', 'PBXContainerItemProxy', containerPortal=project_id, proxyType=1,
                    remoteGlobalIDString=uid(dependency + 'target'), remoteInfo=dependency)
        dependencies.append(add(key + 'dependency', 'PBXTargetDependency', target=uid(dependency + 'target'), targetProxy=proxy))
    settings = dict(PRODUCT_NAME='$(TARGET_NAME)', PRODUCT_BUNDLE_IDENTIFIER='com.mosnagant.' + name.lower(),
                    SWIFT_VERSION='5.0', IPHONEOS_DEPLOYMENT_TARGET='17.0', TARGETED_DEVICE_FAMILY='1,2',
                    CODE_SIGN_STYLE='Automatic', SDKROOT='iphoneos', SUPPORTED_PLATFORMS='iphoneos iphonesimulator',
                    CURRENT_PROJECT_VERSION='1', MARKETING_VERSION='1.0',
                    LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks'])
    if info.exists(): settings.update(GENERATE_INFOPLIST_FILE='NO', INFOPLIST_FILE=name + '/Info.plist')
    else: settings.update(GENERATE_INFOPLIST_FILE='YES', TEST_TARGET_NAME='ThoughtMosaic')
    if entitlements.exists(): settings.update(CODE_SIGN_ENTITLEMENTS=str(entitlements.relative_to(ROOT)))
    if suffix == '.appex':
        settings.update(PRODUCT_BUNDLE_IDENTIFIER='com.mosnagant.thoughtmosaic.' + ('widget' if name.endswith('Widget') else 'share'), APPLICATION_EXTENSION_API_ONLY='YES', SKIP_INSTALL='YES',
                        LD_RUNPATH_SEARCH_PATHS=['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks'])
    target = add(name + 'target', 'PBXNativeTarget', buildConfigurationList=config_list(name, settings), buildPhases=phases,
                 buildRules=[], dependencies=dependencies, name=name, productName=name, productReference=product,
                 productType='com.apple.product-type.' + ('application' if suffix == '.app' else 'app-extension' if suffix == '.appex' else 'bundle.ui-testing'))
    targets.append(target)

product_group = add('products', 'PBXGroup', children=products, name='Products', sourceTree='<group>')
main_group = add('root-group', 'PBXGroup', children=groups + [product_group], sourceTree='<group>')
add('project', 'PBXProject', attributes={'LastUpgradeCheck':'1600', 'BuildIndependentTargetsInParallel':'YES'},
    buildConfigurationList=config_list('project', {'CLANG_ENABLE_MODULES':'YES','SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0'}),
    compatibilityVersion='Xcode 14.0', developmentRegion='zh-Hans', hasScannedForEncodings=0,
    knownRegions=['zh-Hans', 'en', 'Base'], mainGroup=main_group, productRefGroup=product_group,
    projectDirPath='', projectRoot='', targets=targets)

def plist(value, level=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t'*(level+1) + str(k) + ' = ' + plist(v, level+1) + ';\n' for k,v in value.items()) + '\t'*level + '}'
    if isinstance(value, list): return '(' + ', '.join(plist(v, level) for v in value) + (',' if value else '') + ')'
    if isinstance(value, int): return str(value)
    return json.dumps(value, ensure_ascii=False)

OUT.mkdir(parents=True, exist_ok=True)
(OUT / 'project.pbxproj').write_text('// !$*UTF8*$!\n' + plist(dict(archiveVersion=1, classes={}, objectVersion=56, objects=objects, rootObject=project_id)) + '\n')
scheme_dir = OUT / 'xcshareddata/xcschemes'
scheme_dir.mkdir(parents=True, exist_ok=True)
def reference(name):
    suffix = '.app' if name == 'ThoughtMosaic' else '.xctest'
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(name + "target")}" BuildableName="{name + suffix}" BlueprintName="{name}" ReferencedContainer="container:ThoughtMosaic.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference('ThoughtMosaic')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{reference('ThoughtMosaicUITests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('ThoughtMosaic')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference('ThoughtMosaic')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(scheme_dir / 'ThoughtMosaic.xcscheme').write_text(scheme)
print('Generated ThoughtMosaic.xcodeproj (app, widget, share extension, UI tests)')
