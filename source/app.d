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

struct ADKC {
}







import std.traits : RepresentationTypeTuple, FieldTypeTuple;
import std.typetuple : staticMap;
import std.conv;



struct Test0 { char a; }
struct Test1 { int a; }
struct Test2 { int a; float b; }
struct Test3 { Test0 a; Test1 b; Test2 c; }
struct Test4 { Test0 a; Test1 b; Test2 c; Test3 d; Test0 aa; }
struct Test5 { int* a; int[] b; int[12] c; }








void main(){
	alias ECM = EntityComponentManager!(TestComponent);
	auto sm = new SystemManager!(ECM, TestSystem)();

	sm.run();


	
	SoAArray!Test4 xxx;
	auto asd = xxx[0];
//	
//	ToSoA!int aasfdgfrr;
//	
//	
//	xxx ~= XXX(1, 2, Point(4,5,6), [1,2,3]);
//	xxx ~= XXX(2, 2, Point(5,5,6), [2,2,3]);
//	xxx ~= XXX(3, 2, Point(6,5,6), [3,2,3]);
//	xxx ~= XXX(4, 2, Point(7,5,6), [4,2,3]);
//	
//	foreach(i; 0..xxx.length){
//		auto asd = xxx[i];
//		asd.test();
//	}
}
