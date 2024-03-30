
// class OctTree {
//     OctTreeNode@ root;
// }


// class OctTreeNode {
//     OctTreeNode@ parent;
//     array<OctTreeNode@> children;
//     // regions that don't fit in any child
//     array<OctTreeRegions@> regions;
//     // points if we have no children
//     array<vec3> points;
//     // bounding box
//     vec3 max;
//     vec3 min;
//     int depth;


//     void Subdivide() {
//         if (depth >= 10) {
//             return;
//         }
//         vec3 mid = (max + min) / 2;
//         for (int i = 0; i < 2; i++) {
//             for (int j = 0; j < 2; j++) {
//                 for (int k = 0; k < 2; k++) {
//                     OctTreeNode@ child = OctTreeNode();
//                     child.parent = this;
//                     child.depth = depth + 1;
//                     child.min = vec3(i * (mid.x - min.x) + min.x, j * (mid.y - min.y) + min.y, k * (mid.z - min.z) + min.z);
//                     child.max = vec3((i + 1) * (mid.x - min.x) + min.x, (j + 1) * (mid.y - min.y) + min.y, (k + 1) * (mid.z - min.z) + min.z);
//                     children.insertLast(child);
//                 }
//             }
//         }
//     }
// }
