class Utils {
	static int maskFromMap<K>(
		Map<K, bool> maskMap,
		int Function(K key) keyToIntOffset
	) {
		int mask = 0;
		List<int> masks = maskMap.keys.map(
			(key) {
				return 1 << keyToIntOffset(key);
			}
		).toList();
		masks.forEach((m) => mask = mask | m);
		return mask;
	}

	static int hashFromMap<K>(
		Map<K, bool> hashMap,
		int Function(K key) keyToIntOffset
	) {
		List<int> hashes = [];
		hashMap.forEach(
			(key, value) {
				if (value) {
					hashes.add(1 << keyToIntOffset(key));
				}
			}
		);
		return hashes.length == 0 ? 0 : hashes.reduce((value, element) => value | element);
	}
}