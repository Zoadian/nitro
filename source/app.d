import nitro;

import nitro.soa;

struct TestComponent {
	int i;
}

class TestSystem(ECS) {
	void run(ECS ecs) {
	}
}

struct pt {
	int x,y,z;
}

struct XXX {
	int aasd;
	float b;
	int[] c;
	pt d;
}

struct ADKC {
}

void main(){
	alias ECM = EntityComponentManager!(TestComponent);
	auto sm = new SystemManager!(ECM, TestSystem)();

	sm.run();
	
	ArraySoA!XXX xxx;
	
	xxx ~= XXX(1,2,[1,2,3], pt(4,5,6));
	xxx ~= XXX(2,2,[2,2,3], pt(5,5,6));
	xxx ~= XXX(3,2,[3,2,3], pt(6,5,6));
	xxx ~= XXX(4,2,[4,2,3], pt(7,5,6));
	
	foreach(i; 0..xxx.length){
		auto asd = xxx[i];
		asd.test();
	}
}
