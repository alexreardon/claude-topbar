import SwiftUI

/// Claude logo as a SwiftUI Shape, rendered from the official SVG path data.
/// The path is defined in a 24×24 coordinate space.
struct ClaudeLogo: Shape {
    static let terracotta = Color(red: 0xD9/255.0, green: 0x77/255.0, blue: 0x57/255.0)

    /// Returns the logo as a CGPath in a 24×24 coordinate space.
    static func cgPath() -> CGPath {
        let path = CGMutablePath()
        for (i, point) in pathPoints.enumerated() {
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 24.0
        let scaleY = rect.height / 24.0
        return Path(Self.cgPath()).applying(CGAffineTransform(scaleX: scaleX, y: scaleY))
    }

    private static let pathPoints: [CGPoint] = [
        CGPoint(x: 4.7144, y: 15.9555), CGPoint(x: 9.4318, y: 13.3084),
        CGPoint(x: 9.5108, y: 13.0777), CGPoint(x: 9.4318, y: 12.9502),
        CGPoint(x: 9.2011, y: 12.9502), CGPoint(x: 8.4118, y: 12.9016),
        CGPoint(x: 5.7162, y: 12.8287), CGPoint(x: 3.3787, y: 12.7316),
        CGPoint(x: 1.1141, y: 12.6102), CGPoint(x: 0.5434, y: 12.4887),
        CGPoint(x: 0.0091, y: 11.7845), CGPoint(x: 0.0637, y: 11.4323),
        CGPoint(x: 0.5434, y: 11.1105), CGPoint(x: 1.2294, y: 11.1713),
        CGPoint(x: 2.7473, y: 11.2745), CGPoint(x: 5.024, y: 11.4323),
        CGPoint(x: 6.6754, y: 11.5295), CGPoint(x: 9.1222, y: 11.7845),
        CGPoint(x: 9.5108, y: 11.7845), CGPoint(x: 9.5654, y: 11.6266),
        CGPoint(x: 9.4318, y: 11.5295), CGPoint(x: 9.3286, y: 11.4323),
        CGPoint(x: 6.973, y: 9.8356), CGPoint(x: 4.423, y: 8.1477),
        CGPoint(x: 3.0874, y: 7.1763), CGPoint(x: 2.3649, y: 6.6845),
        CGPoint(x: 2.0006, y: 6.2231), CGPoint(x: 1.8428, y: 5.2153),
        CGPoint(x: 2.4985, y: 4.4928), CGPoint(x: 3.3788, y: 4.5535),
        CGPoint(x: 3.6034, y: 4.6142), CGPoint(x: 4.4959, y: 5.3002),
        CGPoint(x: 6.4023, y: 6.7756), CGPoint(x: 8.8916, y: 8.6092),
        CGPoint(x: 9.2559, y: 8.9127), CGPoint(x: 9.4016, y: 8.8095),
        CGPoint(x: 9.4198, y: 8.7367), CGPoint(x: 9.2558, y: 8.4634),
        CGPoint(x: 7.9019, y: 6.0167), CGPoint(x: 6.4569, y: 3.5274),
        CGPoint(x: 5.8134, y: 2.4954), CGPoint(x: 5.6434, y: 1.876),
        CGPoint(x: 5.5402, y: 1.1475), CGPoint(x: 6.287, y: 0.1335),
        CGPoint(x: 6.6997, y: 0), CGPoint(x: 7.6954, y: 0.1336),
        CGPoint(x: 8.1144, y: 0.4978), CGPoint(x: 8.7336, y: 1.9125),
        CGPoint(x: 9.7354, y: 4.1407), CGPoint(x: 11.2897, y: 7.1703),
        CGPoint(x: 11.745, y: 8.0688), CGPoint(x: 11.9879, y: 8.9006),
        CGPoint(x: 12.0789, y: 9.1556), CGPoint(x: 12.2368, y: 9.1556),
        CGPoint(x: 12.2368, y: 9.0099), CGPoint(x: 12.3643, y: 7.3039),
        CGPoint(x: 12.6011, y: 5.2092), CGPoint(x: 12.8318, y: 2.5135),
        CGPoint(x: 12.9107, y: 1.7546), CGPoint(x: 13.2871, y: 0.8439),
        CGPoint(x: 14.0339, y: 0.3521), CGPoint(x: 14.6167, y: 0.6314),
        CGPoint(x: 15.0964, y: 1.3174), CGPoint(x: 15.0296, y: 1.7607),
        CGPoint(x: 14.7443, y: 3.6124), CGPoint(x: 14.1857, y: 6.5145),
        CGPoint(x: 13.8214, y: 8.4574), CGPoint(x: 14.0339, y: 8.4574),
        CGPoint(x: 14.2768, y: 8.2145), CGPoint(x: 15.2603, y: 6.9092),
        CGPoint(x: 16.9117, y: 4.8449), CGPoint(x: 17.6403, y: 4.0253),
        CGPoint(x: 18.4903, y: 3.1207), CGPoint(x: 19.0367, y: 2.6896),
        CGPoint(x: 20.0688, y: 2.6896), CGPoint(x: 20.8278, y: 3.8189),
        CGPoint(x: 20.4878, y: 4.9846), CGPoint(x: 19.4253, y: 6.3324),
        CGPoint(x: 18.5449, y: 7.4738), CGPoint(x: 17.2821, y: 9.1738),
        CGPoint(x: 16.4928, y: 10.5338), CGPoint(x: 16.5657, y: 10.6431),
        CGPoint(x: 16.7539, y: 10.6248), CGPoint(x: 19.6074, y: 10.0178),
        CGPoint(x: 21.1495, y: 9.7384), CGPoint(x: 22.9891, y: 9.4227),
        CGPoint(x: 23.8209, y: 9.8113), CGPoint(x: 23.9119, y: 10.2059),
        CGPoint(x: 23.5841, y: 11.0134), CGPoint(x: 21.6171, y: 11.4991),
        CGPoint(x: 19.3099, y: 11.9605), CGPoint(x: 15.8735, y: 12.7741),
        CGPoint(x: 15.831, y: 12.8045), CGPoint(x: 15.8796, y: 12.8652),
        CGPoint(x: 17.4278, y: 13.0109), CGPoint(x: 18.0896, y: 13.0473),
        CGPoint(x: 19.7106, y: 13.0473), CGPoint(x: 22.7281, y: 13.272),
        CGPoint(x: 23.5173, y: 13.794), CGPoint(x: 23.9909, y: 14.4316),
        CGPoint(x: 23.9119, y: 14.9173), CGPoint(x: 22.6977, y: 15.5366),
        CGPoint(x: 21.0584, y: 15.148), CGPoint(x: 17.2334, y: 14.2373),
        CGPoint(x: 15.9221, y: 13.9094), CGPoint(x: 15.7399, y: 13.9094),
        CGPoint(x: 15.7399, y: 14.0187), CGPoint(x: 16.8328, y: 15.0873),
        CGPoint(x: 18.8363, y: 16.8965), CGPoint(x: 21.3438, y: 19.2279),
        CGPoint(x: 21.4713, y: 19.8047), CGPoint(x: 21.1495, y: 20.2601),
        CGPoint(x: 20.8095, y: 20.2115), CGPoint(x: 18.6056, y: 18.554),
        CGPoint(x: 17.7556, y: 17.8072), CGPoint(x: 15.831, y: 16.1862),
        CGPoint(x: 15.7035, y: 16.1862), CGPoint(x: 15.7035, y: 16.3562),
        CGPoint(x: 16.1467, y: 17.0058), CGPoint(x: 18.4903, y: 20.5272),
        CGPoint(x: 18.6117, y: 21.6079), CGPoint(x: 18.4417, y: 21.96),
        CGPoint(x: 17.8346, y: 22.1725), CGPoint(x: 17.1667, y: 22.0511),
        CGPoint(x: 15.7946, y: 20.1265), CGPoint(x: 14.38, y: 17.959),
        CGPoint(x: 13.2386, y: 16.0162), CGPoint(x: 13.0989, y: 16.0952),
        CGPoint(x: 12.4249, y: 23.3504), CGPoint(x: 12.1093, y: 23.7207),
        CGPoint(x: 11.3807, y: 24), CGPoint(x: 10.7736, y: 23.5386),
        CGPoint(x: 10.4518, y: 22.7918), CGPoint(x: 10.7736, y: 21.3165),
        CGPoint(x: 11.1622, y: 19.3919), CGPoint(x: 11.4779, y: 17.8619),
        CGPoint(x: 11.7632, y: 15.9615), CGPoint(x: 11.9332, y: 15.3301),
        CGPoint(x: 11.9211, y: 15.2876), CGPoint(x: 11.7814, y: 15.3058),
        CGPoint(x: 10.3486, y: 17.273), CGPoint(x: 8.169, y: 20.2176),
        CGPoint(x: 6.4447, y: 22.0632), CGPoint(x: 6.0319, y: 22.2272),
        CGPoint(x: 5.3155, y: 21.8568), CGPoint(x: 5.3823, y: 21.195),
        CGPoint(x: 5.7831, y: 20.6061), CGPoint(x: 8.1691, y: 17.5704),
        CGPoint(x: 9.608, y: 15.6884), CGPoint(x: 10.537, y: 14.6016),
        CGPoint(x: 10.5308, y: 14.4437), CGPoint(x: 10.4762, y: 14.4437),
        CGPoint(x: 4.1377, y: 18.5601), CGPoint(x: 3.0084, y: 18.7058),
        CGPoint(x: 2.5227, y: 18.2504), CGPoint(x: 2.5835, y: 17.5037),
        CGPoint(x: 2.8142, y: 17.2608), CGPoint(x: 4.7206, y: 15.9494),
    ]
}
