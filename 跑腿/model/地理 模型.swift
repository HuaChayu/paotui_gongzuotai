import Foundation
import CoreLocation

/// 地理坐标。同城跑腿的所有空间计算（派单距离、地图落点、路径聚合）都走它。
struct GeoPoint: Codable, Equatable, Sendable {
    var latitude: Double
    var longitude: Double

    /// 默认城市中心：江苏省常州市金坛区
    static let cityCenter = GeoPoint(latitude: 31.7383, longitude: 119.5825)

    /// 以当前点为原点，按米做偏移（正北 / 正东为正）
    func offset(metersNorth: Double, metersEast: Double) -> GeoPoint {
        let dLat = metersNorth / 111_320.0
        let dLng = metersEast / (111_320.0 * cos(latitude * .pi / 180))
        return GeoPoint(latitude: latitude + dLat, longitude: longitude + dLng)
    }

    /// 两点直线距离（米）。同城尺度下平面近似足够，不做 haversine。
    func distance(to other: GeoPoint) -> Double {
        let dLat = (other.latitude - latitude) * 111_320.0
        let dLng = (other.longitude - longitude) * 111_320.0 * cos(latitude * .pi / 180)
        return (dLat * dLat + dLng * dLng).squareRoot()
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
