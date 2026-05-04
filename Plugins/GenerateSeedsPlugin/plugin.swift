import PackagePlugin

/// Build tool plugin that generates static Swift seed types from YAML source files.
///
/// Invokes `GenerateSeedsExec` to read `Sources/NavigatorDAL/Seeds/Question.yaml` and
/// `Jurisdiction.yaml` at build time and produce `GeneratedSeeds.swift` in the plugin
/// work directory. The generated file is compiled into the target that uses this plugin.
@main
struct GenerateSeedsPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let seedsDir = context.package.directoryURL
            .appending(path: "Sources/NavigatorDAL/Seeds")
        let outputFile = context.pluginWorkDirectoryURL
            .appending(path: "GeneratedSeeds.swift")

        return [
            .buildCommand(
                displayName: "Generate Seeds from YAML",
                executable: try context.tool(named: "GenerateSeedsExec").url,
                arguments: [
                    seedsDir.path(percentEncoded: false),
                    outputFile.path(percentEncoded: false),
                ],
                inputFiles: [
                    seedsDir.appending(path: "Question.yaml"),
                    seedsDir.appending(path: "Jurisdiction.yaml"),
                ],
                outputFiles: [outputFile]
            )
        ]
    }
}
