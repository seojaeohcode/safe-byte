// Parametric fit-check prototype, millimetres. Verify purchased modules before printing.
// Export each part separately: openscad -D 'part="base"' -o base.stl case.scad
part = "assembly"; // base, lid, clamp, assembly
outer = [175,115,55];
wall = 3;
lid_thickness = 3;
display_opening = [111,62]; // Replace with actual LCD viewing-window dimensions.
camera_opening = 18;
handle_axes = [35,41];
ubolt_centres = 50;
$fn = 48;

module screw_positions() {
    for(x=[9,outer[0]-9],y=[9,outer[1]-9]) translate([x,y,0]) children();
}
module base() {
    difference() {
        union() {
            difference() {
                cube(outer);
                translate([wall,wall,wall]) cube([outer[0]-wall*2,outer[1]-wall*2,outer[2]]);
            }
            screw_positions() cylinder(d=9,h=outer[2]-1);
        }
        screw_positions() translate([0,0,wall]) cylinder(d=2.7,h=outer[2]);
        // Rear U-bolt mounting points, M8 clearance. Use load-spreading washers.
        for(x=[outer[0]/2-ubolt_centres/2,outer[0]/2+ubolt_centres/2])
            translate([x,outer[1]/2,-1]) cylinder(d=8.6,h=wall+2);
        // Adjustable cable opening and ventilation; keep splash protection in mind.
        translate([-1,40,15]) cube([wall+2,32,18]);
        for(y=[25:8:89]) translate([outer[0]-wall-1,y,20]) cube([wall+2,3,20]);
    }
}
module lid() {
    difference() {
        cube([outer[0],outer[1],lid_thickness]);
        translate([(outer[0]-display_opening[0])/2,35,-1]) cube([display_opening[0],display_opening[1],lid_thickness+2]);
        translate([outer[0]/2,17,-1]) cylinder(d=camera_opening,h=lid_thickness+2);
        screw_positions() translate([0,0,-1]) cylinder(d=3.4,h=lid_thickness+2);
    }
}
module clamp() {
    difference() {
        translate([-40,-16,0]) cube([80,32,18]);
        // Shallow saddle for an oval handle. U-bolt supplies the opposing half.
        translate([0,-17,20]) rotate([-90,0,0]) scale([handle_axes[0]/handle_axes[1],1,1]) cylinder(d=handle_axes[1],h=34);
        for(x=[-ubolt_centres/2,ubolt_centres/2]) translate([x,0,-1]) cylinder(d=8.6,h=20);
    }
}
if(part=="base") base();
else if(part=="lid") lid();
else if(part=="clamp") clamp();
else { base(); translate([0,0,outer[2]+8]) lid(); translate([outer[0]+50,outer[1]/2,0]) clamp(); }
