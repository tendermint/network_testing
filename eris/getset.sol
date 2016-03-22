contract MyContract {
	  mapping(bytes32 => bytes32) public db;

	  function get(bytes32 key) constant returns (bytes32 value) {
		value = db[key];
	  }

	  function set(bytes32 key, bytes32 val) {
		  db[key]=val;
	  }
}
