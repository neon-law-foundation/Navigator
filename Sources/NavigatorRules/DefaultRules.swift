import Foundation

/// Canonical, ordered list of Navigator's built-in linting rules.
///
/// Use the ``all(validQuestionCodes:)`` factory to construct the
/// complete rule set without copying the inline list out of
/// `NavigatorCLI`. Downstream packages that import `NavigatorRules`
/// can layer their own rules on top:
///
/// ```swift
/// import NavigatorRules
///
/// let rules = NavigatorDefaultRules.all() + [C001_NoEmoji(), C002_RequireAuthor()]
/// let engine = RuleEngine(rules: rules)
/// let result = try engine.lint(directory: url)
/// ```
public enum NavigatorDefaultRules {
    /// All built-in Navigator rules in canonical order.
    ///
    /// - Parameter validQuestionCodes: Codes accepted by
    ///   `F104_FlowQuestionCodes`. Defaults to the build-time-generated
    ///   `Seeds.questions` codes; pass a custom set when running
    ///   against a different question registry.
    /// - Returns: An array of `Rule` values in the order Navigator's
    ///   CLI evaluates them.
    public static func all(
        validQuestionCodes: Set<String> = Set(Seeds.questions.map(\.code))
    ) -> [Rule] {
        [
            S101_LineLength(),
            F101_TitleRequired(),
            F102_RespondentTypeRequired(),
            F103_PascalCaseFilename(),
            F104_FlowQuestionCodes(validCodes: validQuestionCodes),
            F105_ConfidentialRequired(),
            F106_StaffReviewRequired(),
            M001_HeadingIncrement(),
            M003_HeadingStyle(),
            M004_ULStyle(),
            M005_ListIndent(),
            M007_ULIndent(),
            M009_NoTrailingSpaces(),
            M010_NoHardTabs(),
            M011_NoReversedLinks(),
            M012_NoMultipleBlanks(),
            M018_NoMissingSpaceATX(),
            M019_NoMultipleSpaceATX(),
            M020_NoMissingSpaceClosedATX(),
            M021_NoMultipleSpaceClosedATX(),
            M022_BlanksAroundHeadings(),
            M023_HeadingStartLeft(),
            M024_NoDuplicateHeading(),
            M026_NoTrailingPunctuation(),
            M027_NoMultipleSpaceBlockquote(),
            M028_NoBlanksBlockquote(),
            M029_OLPrefix(),
            M030_ListMarkerSpace(),
            M031_BlanksAroundFences(),
            M032_BlanksAroundLists(),
            M034_NoBareURLs(),
            M035_HRStyle(),
            M037_NoSpaceInEmphasis(),
            M038_NoSpaceInCode(),
            M039_NoSpaceInLinks(),
            M040_FencedCodeLanguage(),
            M042_NoEmptyLinks(),
            M045_NoAltText(),
            M046_CodeBlockStyle(),
            M047_SingleTrailingNewline(),
            M048_CodeFenceStyle(),
            M049_EmphasisStyle(),
            M050_StrongStyle(),
            M051_LinkFragments(),
            M052_ReferenceLinksImages(),
            M053_LinkImageReferenceDefinitions(),
            M054_LinkImageStyle(),
            M055_TablePipeStyle(),
            M056_TableColumnCount(),
            M058_BlanksAroundTables(),
            M059_DescriptiveLinkText(),
            M060_TableColumnStyle(),
        ]
    }

    /// General-purpose Markdown rule subset.
    ///
    /// Returns the M-family plus `S101_LineLength` — every rule that does
    /// not assume a Navigator notation frontmatter. Use this when running
    /// `navigator lint` against arbitrary Markdown (READMEs, design notes,
    /// blog posts) so the F-rules do not fire on files that were never
    /// meant to carry the standard frontmatter.
    ///
    /// The order matches ``all(validQuestionCodes:)`` with the F-family
    /// removed, so violations sort consistently across both rule sets.
    public static func markdownOnly() -> [Rule] {
        [
            S101_LineLength(),
            M001_HeadingIncrement(),
            M003_HeadingStyle(),
            M004_ULStyle(),
            M005_ListIndent(),
            M007_ULIndent(),
            M009_NoTrailingSpaces(),
            M010_NoHardTabs(),
            M011_NoReversedLinks(),
            M012_NoMultipleBlanks(),
            M018_NoMissingSpaceATX(),
            M019_NoMultipleSpaceATX(),
            M020_NoMissingSpaceClosedATX(),
            M021_NoMultipleSpaceClosedATX(),
            M022_BlanksAroundHeadings(),
            M023_HeadingStartLeft(),
            M024_NoDuplicateHeading(),
            M026_NoTrailingPunctuation(),
            M027_NoMultipleSpaceBlockquote(),
            M028_NoBlanksBlockquote(),
            M029_OLPrefix(),
            M030_ListMarkerSpace(),
            M031_BlanksAroundFences(),
            M032_BlanksAroundLists(),
            M034_NoBareURLs(),
            M035_HRStyle(),
            M037_NoSpaceInEmphasis(),
            M038_NoSpaceInCode(),
            M039_NoSpaceInLinks(),
            M040_FencedCodeLanguage(),
            M042_NoEmptyLinks(),
            M045_NoAltText(),
            M046_CodeBlockStyle(),
            M047_SingleTrailingNewline(),
            M048_CodeFenceStyle(),
            M049_EmphasisStyle(),
            M050_StrongStyle(),
            M051_LinkFragments(),
            M052_ReferenceLinksImages(),
            M053_LinkImageReferenceDefinitions(),
            M054_LinkImageStyle(),
            M055_TablePipeStyle(),
            M056_TableColumnCount(),
            M058_BlanksAroundTables(),
            M059_DescriptiveLinkText(),
            M060_TableColumnStyle(),
        ]
    }
}
