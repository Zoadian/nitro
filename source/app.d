import nitro;

import nitro.soa;

struct TestComponent {
	int i;
}

class TestSystem(ECS) {
	void run(ECS ecs) {
	}
}

struct Point {
	int x,y,z;
}

struct XXX {
	int aasd;
	float b;
	Point d;
	int[] c;
}








import std.traits : RepresentationTypeTuple, FieldTypeTuple;
import std.typetuple : staticMap;
import std.conv;



import std.stdio;

void main(){
	alias ECM = EntityComponentManager!(TestComponent);
	auto sm = new SystemManager!(ECM, TestSystem)();

	sm.run();

	auto e = sm.ecm.createEntity();

	sm.ecm.clearComponents(e);
	

	SoAArray!XXX xxx;
	
	xxx ~= XXX(1, 2, Point(4,5,6), [1,2,3]);
	xxx ~= XXX(20, 20, Point(50,50,60), [20,20,30]);
	xxx ~= XXX(300, 200, Point(600,500,600), [300,200,300]);
	xxx ~= XXX(4000, 2000, Point(7000,5000,6000), [4000,2000,3000]);
	
	xxx.remove(0);
	
	foreach(i; 0..xxx.length){
		auto asd = xxx[i];
		asd.test();
		asd.d.writeln(asd.d.x, asd.d.y, asd.d.z);
		
		"-----------".writeln(i);
	}
}
