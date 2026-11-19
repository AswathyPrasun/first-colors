import Foundation
import SwiftUI
import Testing
@testable import KidsColoring

/// Validates the shipped `content.json` + SVGs. If one of these fails, the art or JSON is wrong.
@MainActor
struct BundledContentTests {
    private let repo = ContentRepository(bundle: .main)

    private var allItems: [ContentItem] {
        KidsColoring.Category.allCases.flatMap { repo.items(in: $0) }
    }

    /// All design tokens are fixed light colors. Without this key, Dark Mode turns system list rows
    /// and titles dark on top of our light backgrounds (unreadable parent area).
    @Test func appIsLockedToLightAppearance() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "UIUserInterfaceStyle") as? String == "Light")
    }

    @Test func shipsTenItemsPerCategoryInOrder() {
        let expected: [KidsColoring.Category: [String]] = [
            .fruits: ["apple", "banana", "orange", "strawberry", "grapes", "watermelon", "pear", "cherry",
                      "pineapple", "mango"],
            .vegetables: ["carrot", "tomato", "broccoli", "eggplant", "corn", "potato", "cucumber", "pumpkin",
                          "onion", "peas"],
            .vehicles: ["car", "bus", "fire_truck", "police_car", "ambulance", "train", "airplane", "boat",
                        "tractor", "rocket"],
            .rescuePups: ["fire_pup", "doctor_pup", "builder_pup", "swim_pup", "farm_pup", "mail_pup",
                          "garden_pup", "snow_pup", "chef_pup", "pilot_pup"],
            .superKids: ["little_star", "heart_boy", "sun_hero", "moon_hero", "cloud_kid", "flower_hero",
                         "rainbow_hero", "cape_kitty", "hero_bear", "music_hero"],
        ]
        for category in KidsColoring.Category.allCases {
            #expect(repo.items(in: category).map(\.id) == expected[category], "\(category)")
        }
    }

    @Test func everyCategoryCoverIsAShippedDrawing() {
        for category in KidsColoring.Category.allCases {
            let cover = category.details.coverItemId
            #expect(repo.item(id: cover)?.category == category, "\(category) cover \(cover)")
            #expect(repo.drawing(for: cover) != nil, "\(category) cover drawing")
        }
    }

    @Test func everyItemHasTextAndAudioNamesInBothLanguages() {
        var audioFiles = Set<String>()
        for item in allItems {
            #expect(!item.name.en.isEmpty, "\(item.id) en name")
            #expect(item.name.ar?.isEmpty == false, "\(item.id) ar name")
            #expect(item.colorSentence?.ar?.isEmpty == false, "\(item.id) sentence")
            for audio in [item.nameAudio, item.colorSentenceAudio] {
                guard let audio, let ar = audio.ar else {
                    Issue.record("\(item.id) missing audio names")
                    continue
                }
                #expect(audioFiles.insert(audio.en).inserted, "duplicate audio \(audio.en)")
                #expect(audioFiles.insert(ar).inserted, "duplicate audio \(ar)")
            }
        }
        // Every category that ships drawings has its spoken name (empty categories are hidden).
        for category in KidsColoring.Category.allCases where !repo.items(in: category).isEmpty {
            #expect(repo.categoryInfo(category)?.nameAudio != nil, "\(category) name audio")
        }
    }

    @Test func everyDrawingLoadsWithAllItsRegions() throws {
        for item in allItems {
            let drawing = try #require(repo.drawing(for: item.id), "\(item.id) drawing")
            #expect(drawing.viewBox == CGRect(x: 0, y: 0, width: 300, height: 300), "\(item.id) viewBox")
            #expect((3...6).contains(drawing.regions.count), "\(item.id) has \(drawing.regions.count) regions")
            #expect(Set(drawing.regions.map(\.id)) == Set(item.regions.map(\.id)), "\(item.id) region ids")
            #expect(!drawing.details.isEmpty, "\(item.id) has a face or details")
        }
    }

    /// Suggestions must be colors the child can actually pick on that picture's screen.
    @Test func suggestedColorsComeFromTheCategoryPalette() {
        for item in allItems {
            let palette = Set(item.category.details.palette.map(\.hex))
            for region in item.regions {
                #expect(!region.suggested.isEmpty, "\(item.id).\(region.id) needs a suggestion")
                for hex in region.suggested {
                    #expect(palette.contains(HexColor.normalized(hex) ?? ""), "\(item.id).\(region.id) \(hex)")
                }
            }
        }
    }

    @Test func artStaysInsideTheCanvasWithRoomForOutlines() throws {
        let safe = CGRect(x: 0, y: 0, width: 300, height: 300).insetBy(dx: 4, dy: 4)
        for item in allItems {
            let drawing = try #require(repo.drawing(for: item.id))
            for region in drawing.regions {
                #expect(safe.contains(region.path.boundingRect), "\(item.id).\(region.id) \(region.path.boundingRect)")
            }
        }
    }

    /// Toddler-sized targets: every region must be big overall (≥ 12% of the drawing width
    /// on its long side) and have a visible spot where a fingertip-sized disk fits.
    @Test func everyRegionIsBigEnoughForAToddlerFinger() throws {
        for item in allItems {
            let drawing = try #require(repo.drawing(for: item.id))
            for region in drawing.regions {
                let metrics = RegionMetrics(region)
                #expect(metrics.longSide >= 36, "\(item.id).\(region.id) long side \(metrics.longSide)")
                #expect(metrics.largestDiskRadius >= 7, "\(item.id).\(region.id) fits r=\(metrics.largestDiskRadius)")
            }
        }
    }

    @Test func drawingsAreCached() throws {
        let first = try #require(repo.drawing(for: "apple"))
        let second = try #require(repo.drawing(for: "apple"))
        #expect(first.regions.count == second.regions.count)
        #expect(repo.drawing(for: "ghost") == nil)
    }
}

/// Size measurements on a region's visible shape (drawing units).
struct RegionMetrics {
    let longSide: CGFloat
    let largestDiskRadius: CGFloat

    init(_ region: DrawingRegion) {
        let bounds = region.visiblePath.boundingRect
        longSide = max(bounds.width, bounds.height)
        var best: CGFloat = 0
        // Coarse search: the largest radius r such that a disk around some grid point is fully inside.
        let radii: [CGFloat] = [30, 24, 18, 14, 11, 9, 7, 5, 3]
        let step: CGFloat = 3
        outer: for r in radii {
            var y = bounds.minY + r
            while y <= bounds.maxY - r {
                var x = bounds.minX + r
                while x <= bounds.maxX - r {
                    if Self.disk(at: CGPoint(x: x, y: y), radius: r, inside: region.visiblePath) {
                        best = r
                        break outer
                    }
                    x += step
                }
                y += step
            }
        }
        largestDiskRadius = best
    }

    private static func disk(at center: CGPoint, radius: CGFloat, inside path: Path) -> Bool {
        guard path.contains(center) else { return false }
        for k in 0..<12 {
            let angle = CGFloat(k) * .pi / 6
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if !path.contains(point) { return false }
        }
        return true
    }
}
