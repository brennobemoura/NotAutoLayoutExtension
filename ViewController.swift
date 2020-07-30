import Foundation
import UIKit
import NotAutoLayout

private var kConstraintsCollection = 0
private var kOldFrame = 0
private var kNALNeedsLayout = 0
extension UIView {
    var constraintCollection: CollectionOfConstraint {
        get { objc_getAssociatedObject(self, &kConstraintsCollection) as? CollectionOfConstraint ?? {
            let collection = CollectionOfConstraint([.centerX, .centerY, .fitHeight, .fitWidth])
            self.constraintCollection = collection
            return collection
        }()}
        set { objc_setAssociatedObject(self, &kConstraintsCollection, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }

    var oldFrame: CGRect? {
        get { objc_getAssociatedObject(self, &kOldFrame) as? CGRect }
        set { objc_setAssociatedObject(self, &kOldFrame, newValue, .OBJC_ASSOCIATION_COPY) }
    }

    var needsNALLayout: Bool {
        get { objc_getAssociatedObject(self, &kNALNeedsLayout) as? Bool ?? true }
        set { objc_setAssociatedObject(self, &kNALNeedsLayout, newValue, .OBJC_ASSOCIATION_COPY) }
    }
    

    static func commit(collection: CollectionOfConstraint, in view: UIView) {
        guard let superview = view.superview else {
            return
        }

        collection.lazyLayout(on: superview, subview: view)
    }

    func setNeedsNALLayout() {
        self.needsNALLayout = true
    }

    func addNALConstraint(_ constraint: Constraint) {
        self.constraintCollection.append(constraint)
        self.setNeedsNALLayout()
        self.layoutNAL()
    }

    func addNALSubview(_ view: UIView) {
        self.addSubview(view)
        self.setNeedsNALLayout()
        view.setNeedsNALLayout()
        self.layoutNAL()
    }

    func layoutNAL() {
        guard self.needsNALLayout else {
            return
        }

        self.needsNALLayout = false
        let oldFrame = self.oldFrame ?? self.frame
        Self.commit(collection: self.constraintCollection, in: self)
        self.oldFrame = self.frame

        if oldFrame.size != self.frame.size {
            self.subviews.forEach {
                $0.layoutNAL()
                $0.setNeedsNALLayout()
            }
        }
    }
}

class AutoView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        UpdateLayout.shared.append(self)
    }
}

class UpdateLayout {
    static var shared: UpdateLayout = .init()

    var pending: [UIView] = []
    var isRunning: Bool = false

    func append(_ view: UIView) {
//        self.pending.append(view)
//        if self.isRunning {
//            return
//        }
//
//        self.isRunning = true
//        self.consume()
    }

    func consume() {
        guard let first = self.pending.first else {
            self.isRunning = false
            return
        }

        self.pending.removeFirst()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0015) {
            first.backgroundColor = [UIColor.blue, .red, .yellow, .cyan, .brown, .black, .darkGray, .green].filter {
                (first.backgroundColor ?? .white) != $0
            }.randomElement() ?? .white

            self.consume()
        }
    }
}

class View: UIView {

    override var frame: CGRect {
        didSet {
            if oldValue.size != self.frame.size {
                self.setNeedsNALLayout()
                self.layoutNAL()
                UpdateLayout.shared.append(self)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.layoutNAL()
    }
}

class AutoViewController: UIViewController {
    override func loadView() {
        self.view = AutoView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .red
        let view = AutoView()
        view.backgroundColor = .blue

        self.view.addSubview(view)
        self.deep(count: 5000, self.view, view)
    }

    func deep(count: Int, _ superview: UIView,_ subview: UIView) {
        guard count > 0 else {
            return
        }

        subview.translatesAutoresizingMaskIntoConstraints = false

        subview.centerXAnchor.constraint(equalTo: superview.centerXAnchor).isActive = true
        subview.centerYAnchor.constraint(equalTo: superview.centerYAnchor).isActive = true
        subview.heightAnchor.constraint(equalTo: superview.heightAnchor, multiplier: 0.975).isActive = true
        subview.widthAnchor.constraint(equalTo: superview.widthAnchor, multiplier: 0.975).isActive = true

        let view = AutoView()
        view.backgroundColor = [UIColor.blue, .red, .yellow, .cyan, .brown, .black, .darkGray, .green].randomElement() ?? .white

        subview.addSubview(view)
        self.deep(count: count - 1, subview, view)
    }
}

class NOViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.backgroundColor = .red

        let view = View()
        view.backgroundColor = .blue

        self.view.addNALSubview(view)
        self.deep(count: 5000, self.view, view)
    }

    func deep(count: Int, _ superview: UIView,_ subview: UIView) {
        guard count > 0 else {
            return
        }

        subview.addNALConstraint(.height(superview.nal.layoutGuides, multipliedBy: 0.975))
        subview.addNALConstraint(.width(superview.nal.layoutGuides, multipliedBy: 0.975))

        let view = View()
        view.backgroundColor = [UIColor.blue, .red, .yellow, .cyan, .brown, .black, .darkGray, .green].randomElement() ?? .white

        subview.addNALSubview(view)
        self.deep(count: count - 1, subview, view)
    }

//    func loop(view: UIView) {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
//            view.frame.origin.x += 1
//            self.loop(view: view)
//        }
//    }

    override func loadView() {
        self.view = View()
    }
}

typealias ViewController = AutoViewController

extension CollectionOfConstraint {
    func lazyLayout(on superview: UIView, subview: UIView) {
        switch self.form {
        case .top:
            if let centerXConstraint = self[.centerX] {
                return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                    .setCenter(centerXConstraint)
                    .setTop(self[.top])
                    .setHeight(self[.height])
                    .setWidth(self[.width])
                })
            }

            return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setLeft(self[.leading])
                .setRight(self[.trailing])
                .setTop(self[.top])
                .setHeight(self[.height])
            })

        case .topLeft:
            return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setLeft(self[.leading])
                .setTop(self[.top])
                .setHeight(self[.height])
                .setWidth(self[.width])
            })
        case .topRight:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setRight(self[.trailing])
                .setTop(self[.top])
                .setHeight(self[.height])
                .setWidth(self[.width])
            })
        case .right:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setRight(self[.trailing])
                .setMiddle(self[.centerY])
                .setHeight(self[.height])
                .setWidth(self[.width])
            })
        case .left:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setLeft(self[.leading])
                .setMiddle(self[.centerY])
                .setHeight(self[.height])
                .setWidth(self[.width])
            })
        case .bottom:
            if let centerXConstraint = self[.centerX] {
                return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                    .setCenter(centerXConstraint)
                    .setBottom(self[.bottom])
                    .setHeight(self[.height])
                    .setWidth(self[.width])
                })
            }

            return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setLeft(self[.leading])
                .setRight(self[.trailing])
                .setBottom(self[.bottom])
                .setHeight(self[.height])
            })

        case .bottomLeft:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setLeft(self[.leading])
                .setBottom(self[.bottom])
                .setHeight(self[.height])
                .setWidth(self[.width])
            })
        case .bottomRight:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setRight(self[.trailing])
                .setBottom(self[.bottom])
                .setHeight(self[.height])
                .setWidth(self[.width])
            })
        case .center:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setCenter(self[.centerX])
                .setMiddle(self[.centerY])
                .setWidth(self[.width])
                .setHeight(self[.height])
            })
        case .centerY:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setLeft(self[.leading])
                .setRight(self[.trailing])
                .setMiddle(self[.centerY])
                .setHeight(self[.height])
            })
        case .centerX:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setCenter(self[.centerX])
                .setTop(self[.top])
                .setBottom(self[.bottom])
                .setWidth(self[.width])
            })
        case .edges:
        return superview.nal.layout(subview, with: subview.nal.makeLayout { $0
                .setLeft(self[.leading])
                .setRight(self[.trailing])
                .setTop(self[.top])
                .setBottom(self[.bottom])
            })
        }
    }
}

extension CollectionOfConstraint {
    func apply<View: LayoutInfoStorable>(on superview: View, subview: UIView) where View: UIView {
        switch self.form {
        case .top:
            if let centerXConstraint = self[.centerX] {
                return superview.nal.setupSubview(subview, setup: {
                    $0.setDefaultLayout {
                        $0.setCenter(centerXConstraint)
                            .setTop(self[.top])
                            .setHeight(self[.height])
                            .setWidth(self[.width])
                    }
                    .addToParent()
                })
            }

            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0.setLeft(self[.leading])
                        .setRight(self[.trailing])
                        .setTop(self[.top])
                        .setHeight(self[.height])
                }
                .addToParent()
            })

        case .topLeft:
            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0.setLeft(self[.leading])
                        .setTop(self[.top])
                        .setHeight(self[.height])
                        .setWidth(self[.width])
                }
                .addToParent()
            })
        case .topRight:
            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0
                    .setRight(self[.trailing])
                        .setTop(self[.top])
                        .setHeight(self[.height])
                        .setWidth(self[.width])
                }
                .addToParent()
            })
        case .right:
            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0
                    .setRight(self[.trailing])
                        .setMiddle(self[.centerY])
                        .setHeight(self[.height])
                        .setWidth(self[.width])
                }
                .addToParent()
            })
        case .left:
            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0
                    .setLeft(self[.leading])
                        .setMiddle(self[.centerY])
                        .setHeight(self[.height])
                        .setWidth(self[.width])
                }
                .addToParent()
            })
        case .bottom:
            if let centerXConstraint = self[.centerX] {
                return superview.nal.setupSubview(subview, setup: {
                    $0.setDefaultLayout {
                        $0.setCenter(centerXConstraint)
                            .setBottom(self[.bottom])
                            .setHeight(self[.height])
                            .setWidth(self[.width])
                    }
                    .addToParent()
                })
            }

            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0.setLeft(self[.leading])
                        .setRight(self[.trailing])
                        .setBottom(self[.bottom])
                        .setHeight(self[.height])
                }
                .addToParent()
            })

        case .bottomLeft:
            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0.setLeft(self[.leading])
                        .setBottom(self[.bottom])
                        .setHeight(self[.height])
                        .setWidth(self[.width])
                }
                .addToParent()
            })
        case .bottomRight:
        return superview.nal.setupSubview(subview, setup: {
            $0.setDefaultLayout {
                $0
                .setRight(self[.trailing])
                    .setBottom(self[.bottom])
                    .setHeight(self[.height])
                    .setWidth(self[.width])
            }
            .addToParent()
        })
        case .center:
            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0
                        .setCenter(self[.centerX])
                        .setMiddle(self[.centerY])
                        .setWidth(self[.width])
                        .setHeight(self[.height])
                }
                .addToParent()
            })
        case .centerY:
            return superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0
                        .setLeft(self[.leading])
                        .setRight(self[.trailing])
                        .setMiddle(self[.centerY])
                        .setHeight(self[.height])
                }
                .addToParent()
            })
        case .centerX:
        return superview.nal.setupSubview(subview, setup: {
            $0.setDefaultLayout {
                $0
                    .setCenter(self[.centerX])
                    .setTop(self[.top])
                    .setBottom(self[.bottom])
                    .setWidth(self[.width])
            }
            .addToParent()
        })
        case .edges:
            superview.nal.setupSubview(subview, setup: {
                $0.setDefaultLayout {
                    $0
                    .setLeft(self[.leading])
                    .setRight(self[.trailing])
                        .setTop(self[.top])
                        .setBottom(self[.bottom])
                }
                .addToParent()
            })
        }
    }
}

//class View: LayoutInfoStoredView {
//    var collectionOfConstraints: CollectionOfConstraint = .init([])
//    weak var view: UIView!
//
//    func reload() {
//        self.collectionOfConstraints.apply(on: self, subview: self.view)
//    }
//
//    func test() {
//        let view = UIView()
//        view.backgroundColor = .blue
//        self.view = view
//        self.reload()
//    }
//
//    func constraint(_ constraint: Constraint) {
//        self.collectionOfConstraints.append(constraint)
//        self.reload()
//    }
//}

enum ConstraintRelation {
    case top
    case bottom
    case leading
    case trailing
    case centerY
    case centerX
    case width
    case height

    var importancy: Int {
        switch self {
        case .top, .bottom, .leading, .trailing:
            return 1
        case .width, .height:
            return 2
        case .centerX, .centerY:
            return 3
        }
    }

    var auto: Constraint {
        switch self {
        case .top:
            return .top { $0.top }
        case .bottom:
            return .bottom { $0.bottom }
        case .leading:
            return .leading { $0.leading }
        case .trailing:
            return .trailing { $0.trailing }
        case .centerY:
            return .centerY { $0.middle }
        case .centerX:
            return .centerX { $0.center }
        case .width:
            return .fitWidth
        case .height:
            return .fitHeight
        }
    }
}

extension LayoutMaker where Property: LayoutPropertyCanStoreCenterType {

    func setCenter(_ constraint: Constraint) -> LayoutMaker<Property.WillSetCenterProperty> {
        guard let layout = constraint.layoutMaker.constructor else {
            fatalError()
        }

        if let guide = constraint.toGuide {
            return self.setCenter(by: { layout($0.makeGuide(from: guide.frame)) })
        }

        return self.setCenter(by: { layout($0) })
    }
}

extension LayoutMaker where Property: LayoutPropertyCanStoreMiddleType {

    func setMiddle(_ constraint: Constraint) -> LayoutMaker<Property.WillSetMiddleProperty> {
        guard let layout = constraint.layoutMaker.constructor else {
            fatalError()
        }

        if let guide = constraint.toGuide {
            return self.setMiddle(by: { layout($0.makeGuide(from: guide.frame)) })
        }

        return self.setMiddle(by: { layout($0) })
    }
}

extension LayoutMaker where Property: LayoutPropertyCanStoreTopType {

    func setTop(_ constraint: Constraint) -> LayoutMaker<Property.WillSetTopProperty> {
        guard let layout = constraint.layoutMaker.constructor else {
            fatalError()
        }

        if let guide = constraint.toGuide {
            return self.setTop(by: { layout($0.makeGuide(from: guide.frame)) })
        }

        return self.setTop(by: { layout($0) })
    }
}

extension LayoutMaker where Property: LayoutPropertyCanStoreBottomType {

    func setBottom(_ constraint: Constraint) -> LayoutMaker<Property.WillSetBottomProperty> {
        guard let layout = constraint.layoutMaker.constructor else {
            fatalError()
        }

        if let guide = constraint.toGuide {
            return self.setBottom(by: { layout($0.makeGuide(from: guide.frame)) })
        }

        return self.setBottom(by: { layout($0) })
    }
}

extension LayoutMaker where Property: LayoutPropertyCanStoreLeftType {

    func setLeft(_ constraint: Constraint) -> LayoutMaker<Property.WillSetLeftProperty> {
        guard let layout = constraint.layoutMaker.constructor else {
            fatalError()
        }

        if let guide = constraint.toGuide {
            return self.setLeft(by: { layout($0.makeGuide(from: guide.frame)) })
        }

        return self.setLeft(by: { layout($0) })
    }
}

extension LayoutMaker where Property: LayoutPropertyCanStoreRightType {

    func setRight(_ constraint: Constraint) -> LayoutMaker<Property.WillSetRightProperty> {
        guard let layout = constraint.layoutMaker.constructor else {
            fatalError()
        }

        if let guide = constraint.toGuide {
            return self.setRight(by: { layout($0.makeGuide(from: guide.frame)) })
        }

        return self.setRight(by: { layout($0) })
    }
}

extension LayoutMaker where Property: LayoutPropertyCanStoreHeightType {

    func setHeight(_ constraint: Constraint) -> LayoutMaker<Property.WillSetHeightProperty> {
        if let guide = constraint.toGuide {
            guard let layout = constraint.layoutMaker.constructor else {
                fatalError()
            }

            return self.setHeight(by: { layout($0.makeGuide(from: guide.frame)) })
        }

        switch constraint.layoutMaker {
        case .equalTo(let maker):
            return self.setHeight(by: { maker($0) })
        case .fit:
            return self.fitHeight()
        }
    }
}

extension LayoutMaker where Property: LayoutPropertyCanStoreWidthType {

    func setWidth(_ constraint: Constraint) -> LayoutMaker<Property.WillSetWidthProperty> {
        if let guide = constraint.toGuide {
            guard let layout = constraint.layoutMaker.constructor else {
                fatalError()
            }

            return self.setWidth(by: { layout($0.makeGuide(from: guide.frame)) })
        }

        switch constraint.layoutMaker {
        case .equalTo(let maker):
            return self.setWidth(by: { maker($0) })
        case .fit:
            return self.fitWidth()
        }
    }
}

extension Array where Element == Constraint {
    func layout(from relation: ConstraintRelation) -> ((ViewLayoutGuides) -> Float)? {
        self.first(where: { $0.relation == relation })?.layoutMaker.constructor
    }

    func layoutDimention(from relation: ConstraintRelation) -> Constraint.Maker? {
        switch relation {
        case .height:
            guard let height = self.first(where: { $0.relation == .height }) else {
                return .fit
            }

            return height.layoutMaker
        case .width:
            guard let width = self.first(where: { $0.relation == .width }) else {
                return .fit
            }

            return width.layoutMaker
        default:
            return nil
        }
    }

    func layoutOrRegular(from relation: ConstraintRelation) -> ((ViewLayoutGuides) -> Float) {
        switch relation {
            case .top:
                return self.layout(from: relation) ?? { $0.top }
            case .bottom:
                return self.layout(from: relation) ?? { $0.bottom }
            case .leading:
                return self.layout(from: relation) ?? { $0.leading }
            case .trailing:
                return self.layout(from: relation) ?? { $0.trailing }
            case .centerY:
                return self.layout(from: relation) ?? { $0.center }
            case .centerX:
                return self.layout(from: relation) ?? { $0.middle }
            case .width:
                fatalError()
            case .height:
            fatalError()
        }
    }
}

extension Set where Element == ConstraintRelation {
    var importancy: Int {
        self.reduce(0) {
            $0 + $1.importancy
        }
    }

    var asConstraintForm: ConstraintForm {
        let nilForm = ConstraintForm.allCases.reduce([(ConstraintForm, Set<Element>)]()) { s, f in
            s + f.filter.asArrayOfSets.map { (f, $0) }
        }
        .max { $0.1.intersection(self).count < $1.1.intersection(self).count }?.0

        guard let form = nilForm else {
            fatalError()
        }

        return form
    }
}

indirect enum ConstraintFilter {
    case exact(Set<ConstraintRelation>)
    case or(ConstraintFilter, ConstraintFilter)

    var asArrayOfSets: [Set<ConstraintRelation>] {
        switch self {
        case .exact(let set):
            return [set]
        case .or(let left, let right):
            return left.asArrayOfSets + right.asArrayOfSets
        }
    }

    func contains(_ element: ConstraintRelation) -> Bool {
        switch self {
        case .exact(let setOfRelation):
            return setOfRelation.contains(element)

        case .or(let leftFilter, let rightFilter):
            return leftFilter.contains(element) || rightFilter.contains(element)
        }
    }

    func setOfRelations(with element: ConstraintRelation) -> Set<ConstraintRelation>? {
        switch self {
        case .exact(let setOfRelation):
            return setOfRelation.contains(element) ? setOfRelation : nil

        case .or(let leftFilter, let rightFilter):
            if let setOfRelation = leftFilter.setOfRelations(with: element) {
                return setOfRelation
            }

            return rightFilter.setOfRelations(with: element)
        }
    }
}

enum ConstraintForm: CaseIterable {
    case top
    case topLeft
    case topRight
    case right
    case left
    case bottom
    case bottomLeft
    case bottomRight
    case center
    case centerY
    case centerX
    case edges

    static func revolse(_ array: Set<ConstraintRelation>, new: ConstraintRelation) -> Set<ConstraintRelation> {
        let array = array.union(Set(arrayLiteral: new))
        let filters = self.allCases.reduce([Set<ConstraintRelation>]()) {
            $0 + $1.filter.asArrayOfSets
        }

        let intersectionWithArray = filters.map {
            ($0, $0.intersection(array))
        }

        guard let bestMatch = (intersectionWithArray
            .sorted(by: { $0.1.count > $1.1.count })
            .first(where: {
                $0.0.contains(new)
            })) else {
                fatalError()
            }

        return bestMatch.0
    }

    static func integrity(_ array: [Constraint]) -> [Constraint] {
        let unique = Set(array.map { $0.relation })


        let filters: [(Set<ConstraintRelation>, Int)] = {
            let filters = self.allCases.reduce([Set<ConstraintRelation>]()) {
                $0 + $1.filter.asArrayOfSets
            }

            let intersectionWithArray = filters.map {
                ($0, $0.intersection(unique).count)
            }

            var max = 0
            for filter in intersectionWithArray {
                if filter.1 > max {
                    max = filter.1
                }
            }

            return intersectionWithArray.filter {
                $0.1 == max
            }
        }()

        guard let bestFilter = filters.max(by: { $0.0.importancy < $1.0.importancy })  else {
            fatalError()
        }

        return bestFilter.0.map { element in
            array.first(where: { $0.relation == element }) ?? element.auto
        }
    }

    var filter: ConstraintFilter {
        switch self {
        case .top:
            return .or(
                .exact([.top, .centerX, .height, .width]),
                .exact([.top, .height, .leading, .trailing])
            )
        case .bottom:
            return .or(
                .exact([.bottom, .centerX, .height, .width]),
                .exact([.bottom, .height, .leading, .trailing])
            )

        case .topLeft:
            return .exact([.top, .height, .leading, .width])

        case .topRight:
            return .exact([.top, .height, .trailing, .width])

        case .center:
            return .exact([.centerX, .centerY, .height, .width])

        case .right:
            return .exact([.centerY, .height, .trailing, .width])

        case .left:
            return .exact([.centerY, .height, .leading, .width])

        case .bottomLeft:
            return .exact([.bottom, .height, .leading, .width])

        case .bottomRight:
            return .exact([.bottom, .height, .trailing, .width])

        case .edges:
            return .exact([.top, .bottom, .trailing, .leading])

        case .centerX:
            return .exact([.bottom, .centerX, .top, .width])

        case .centerY:
            return .exact([.centerY, .height, .leading, .trailing])
        }
    }
}

struct Constraint: Hashable {
    static func == (lhs: Constraint, rhs: Constraint) -> Bool {
        lhs.relation == rhs.relation
    }

    enum Maker {
        case equalTo((LayoutGuideRepresentable) -> Float)
        case fit

        var constructor: ((LayoutGuideRepresentable) -> Float)? {
            switch self {
            case .equalTo(let handler):
                return handler
            case .fit:
                return nil
            }
        }
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.relation)
    }

    let relation: ConstraintRelation
    let layoutMaker: Maker
    let toGuide: LayoutGuideRepresentable?

    private init(_ relation: ConstraintRelation,_ maker: Maker, toGuide guide: LayoutGuideRepresentable? = nil) {
        self.relation = relation
        self.layoutMaker = maker
        self.toGuide = guide
    }
}

extension Constraint {

    static var top: Constraint {
        .top(equalTo: 0)
    }

    static func top(equalTo constant: Float) -> Constraint {
        .init(
            .top,
            .equalTo { $0.top + constant }
        )
    }

    static func top(_ guide: LayoutGuideRepresentable, equalTo constant: Float) -> Constraint {
        .init(
            .top,
            .equalTo { $0.top + constant },
            toGuide: guide
        )
    }

    static func top(_ guide: LayoutGuideRepresentable,_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .top,
            .equalTo(layoutMaker),
            toGuide: guide
        )
    }

    static func top(_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .top,
            .equalTo(layoutMaker)
        )
    }
}

extension Constraint {

    static var bottom: Constraint {
        .bottom(equalTo: 0)
    }

    static func bottom(equalTo constant: Float) -> Constraint {
        .init(
            .bottom,
            .equalTo { $0.bottom + constant }
        )
    }

    static func bottom(_ guide: LayoutGuideRepresentable, equalTo constant: Float) -> Constraint {
        .init(
            .bottom,
            .equalTo { $0.bottom + constant },
            toGuide: guide
        )
    }

    static func bottom(_ guide: LayoutGuideRepresentable,_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .bottom,
            .equalTo(layoutMaker),
            toGuide: guide
        )
    }

    static func bottom(_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .bottom,
            .equalTo(layoutMaker)
        )
    }
}

extension Constraint {

    static var leading: Constraint {
        .leading(equalTo: 0)
    }

    static func leading(equalTo constant: Float) -> Constraint {
        .init(
            .leading,
            .equalTo { $0.leading + constant }
        )
    }

    static func leading(_ guide: LayoutGuideRepresentable, equalTo constant: Float) -> Constraint {
        .init(
            .leading,
            .equalTo { $0.leading + constant },
            toGuide: guide
        )
    }

    static func leading(_ guide: LayoutGuideRepresentable,_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .leading,
            .equalTo(layoutMaker),
            toGuide: guide
        )
    }

    static func leading(_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .leading,
            .equalTo(layoutMaker)
        )
    }
}

extension Constraint {

    static var trailing: Constraint {
        .trailing(equalTo: 0)
    }

    static func trailing(equalTo constant: Float) -> Constraint {
        .init(
            .trailing,
            .equalTo { $0.trailing + constant }
        )
    }

    static func trailing(_ guide: LayoutGuideRepresentable, equalTo constant: Float) -> Constraint {
        .init(
            .trailing,
            .equalTo { $0.trailing + constant },
            toGuide: guide
        )
    }

    static func trailing(_ guide: LayoutGuideRepresentable,_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .trailing,
            .equalTo(layoutMaker),
            toGuide: guide
        )
    }

    static func trailing(_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .trailing,
            .equalTo(layoutMaker)
        )
    }
}

extension Constraint {

    static var centerX: Constraint {
        .centerX { $0.center }
    }

    static func centerX(equalTo constant: Float) -> Constraint {
        .init(
            .centerX,
            .equalTo { $0.center + constant }
        )
    }

    static func centerX(_ guide: LayoutGuideRepresentable, equalTo constant: Float) -> Constraint {
        .init(
            .centerX,
            .equalTo { $0.center + constant },
            toGuide: guide
        )
    }

    static func centerX(_ guide: LayoutGuideRepresentable,_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .centerX,
            .equalTo(layoutMaker),
            toGuide: guide
        )
    }

    static func centerX(_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .centerX,
            .equalTo(layoutMaker)
        )
    }
}

extension Constraint {

    static var centerY: Constraint {
        .centerY { $0.middle }
    }

    static func centerY(equalTo constant: Float) -> Constraint {
        .init(
            .centerY,
            .equalTo { $0.middle + constant }
        )
    }

    static func centerY(_ guide: LayoutGuideRepresentable, equalTo constant: Float) -> Constraint {
        .init(
            .centerY,
            .equalTo { $0.middle + constant },
            toGuide: guide
        )
    }

    static func centerY(_ guide: LayoutGuideRepresentable,_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .centerY,
            .equalTo(layoutMaker),
            toGuide: guide
        )
    }

    static func centerY(_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .centerY,
            .equalTo(layoutMaker)
        )
    }
}

extension Constraint {

    static func height(equalTo constant: Float) -> Constraint {
        .init(
            .height,
            .equalTo { _ in constant }
        )
    }

    static func height(_ guide: LayoutGuideRepresentable, multipliedBy multiplier: Float) -> Constraint {
        .init(
            .height,
            .equalTo {$0.height * multiplier },
            toGuide: guide
        )
    }

    static func height(_ guide: LayoutGuideRepresentable,_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .height,
            .equalTo(layoutMaker),
            toGuide: guide
        )
    }

    static func height(_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .height,
            .equalTo(layoutMaker)
        )
    }

    static var fitHeight: Constraint {
        .init(
            .height,
            .fit
        )
    }
}

extension Constraint {

    static func width(equalTo constant: Float) -> Constraint {
        .init(
            .width,
            .equalTo { _ in constant }
        )
    }

    static func width(_ guide: LayoutGuideRepresentable, multipliedBy multiplier: Float) -> Constraint {
        .init(
            .width,
            .equalTo { $0.width * multiplier },
            toGuide: guide
        )
    }

    static func width(_ guide: LayoutGuideRepresentable,_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .width,
            .equalTo(layoutMaker),
            toGuide: guide
        )
    }

    static func width(_ layoutMaker: @escaping (LayoutGuideRepresentable) -> Float) -> Constraint {
        .init(
            .width,
            .equalTo(layoutMaker)
        )
    }

    static var fitWidth: Constraint {
        .init(
            .width,
            .fit
        )
    }
}

struct CollectionOfConstraint {
    enum Property: Hashable {
        case generated(Constraint)
        case setByUser(Constraint)

        var constraint: Constraint {
            switch self {
            case .generated(let constraint):
                return constraint
            case .setByUser(let constraint):
                return constraint
            }
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.constraint)
        }

        var isAutoGenerated: Bool {
            switch self {
            case .generated:
                return true
            case .setByUser:
                return false
            }
        }

        static func unique(properties: [Property]) -> [Property] {
            let reversedProperties = properties.reversed()
            let uniqueConstraint = reversedProperties.map {
                $0.constraint
            }.unique()

            var uniqueProperties: [Property] = []
            var uniqueRelation: Set<ConstraintRelation> = .init()

            for constraint in uniqueConstraint {
                if !uniqueRelation.contains(constraint.relation) {
                    uniqueRelation.insert(constraint.relation)

                    if let property = properties.first(where: { $0.constraint.relation == constraint.relation }) {
                        uniqueProperties.append(property)
                    }
                }
            }

            return uniqueProperties
        }
    }

    private var storedForm: ConstraintForm?
    var form: ConstraintForm {
        self.storedForm!
    }
    private var properties: Set<Property>
    private var generateForm: ConstraintForm {
        Set(self.properties.map { $0.constraint.relation }).asConstraintForm
    }

    init(_ collectionOf: Set<Constraint>) {
        let collection = ConstraintForm.integrity(collectionOf.map {
            $0
        })
        self.properties = Set(collection.map {
            collectionOf.contains($0) ? .setByUser($0) : .generated($0)
        })
        self.storedForm = nil
        self.storedForm = self.generateForm
    }

    mutating
    func setArray(_ array: [Property]) {
        self.properties = Set(Property.unique(properties: array))
        self.storedForm = self.generateForm
    }

    mutating func append(_ constraint: Constraint) {
        if self.properties.contains(where: { $0.constraint.relation == constraint.relation }) {
            self.setArray(self.properties.filter {
                $0.constraint.relation != constraint.relation
            } + [.setByUser(constraint)])
            return
        }

        let newArray = self.properties.filter { !$0.isAutoGenerated } + [.setByUser(constraint)]

        self.setArray(
            ConstraintForm.revolse(
                Set(newArray.map { $0.constraint.relation }),
                new: constraint.relation
            )
            .compactMap { element in
                newArray.first(where: { $0.constraint.relation == element }) ?? .generated(element.auto)
            }
        )
    }

    subscript(_ relation: ConstraintRelation) -> Constraint! {
        self.properties.first(where: { $0.constraint.relation == relation })?.constraint
    }
}

extension Array where Element == Constraint {
    func unique() -> [Element] {
        self.reduce([Constraint]()) {
            if $0.contains($1.relation) {
                return $0
            }

            return $0 + [$1]
        }
    }

    func contains(_ relation: ConstraintRelation) -> Bool {
        self.contains {
            $0.relation == relation
        }
    }
}
