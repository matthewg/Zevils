<?
	$des_shifts = array(0, 1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1);

	$des_permute1 = array(
		57, 49, 41, 33, 25, 17, 9,
		1, 58, 50, 42, 34, 26, 18,
		10, 2, 59, 51, 43, 35, 27,
		19, 11, 3, 60, 52, 44, 36,
		63, 55, 47, 39, 31, 23, 15,
		7, 62, 54, 46, 38, 30, 22,
		14, 6, 61, 53, 45, 37, 29,
		21, 13, 5, 28, 20, 12, 4
	);

	$des_permute2 = array(
		14, 17, 11, 24, 1, 5,
		3, 28, 15, 6, 21, 10,
		23, 19, 12, 4, 26, 8,
		16, 7, 27, 20, 13, 2,
		41, 52, 31, 37, 47, 55,
		30, 40, 51, 45, 33, 48,
		44, 49, 39, 56, 34, 53,
		46, 42, 50, 36, 29, 32
	);

	$des_initial_permute = array(
		58, 50, 42, 34, 26, 18, 10, 2,
		60, 52, 44, 36, 28, 20, 12, 4,
		62, 54, 46, 38, 30, 22, 14, 6,
		64, 56, 48, 40, 32, 24, 16, 8,
		57, 49, 41, 33, 25, 17, 9, 1,
		59, 51, 43, 35, 27, 19, 11, 3,
		61, 53, 45, 37, 29, 21, 13, 5,
		63, 55, 47, 39, 31, 23, 15, 7
	);

	$des_permute_e = array(
		32, 1, 2, 3, 4, 5,
		4, 5, 6, 7, 8, 9,
		8, 9, 10, 11, 12, 13,
		12, 13, 14, 15, 16, 17,
		16, 17, 18, 19, 20, 21,
		20, 21, 22, 23, 24, 25,
		24, 25, 26, 27, 28, 29,
		28, 29, 30, 31, 32, 1
	);

	$des_sbox = array(
		array( //S1
			array(14, 4, 13, 1, 2, 15, 11, 8, 3, 10, 6, 12, 5, 9, 0, 7),
			array(0, 15, 7, 4, 14, 2, 13, 1, 10, 6, 12, 11, 9, 5, 3, 8),
			array(4, 1, 14, 8, 13, 6, 2, 11, 15, 12, 9, 7, 3, 10, 5, 0),
			array(15, 12, 8, 2, 4, 9, 1, 7, 5, 11, 3, 14, 10, 0, 6, 13)
		), array( //S2
			array(15, 1, 8, 14, 6, 11, 3, 4, 9, 7, 2, 13, 12, 0, 5, 10),
			array(3, 13, 4, 7, 15, 2, 8, 14, 12, 0, 1, 10, 6, 9, 11, 5),
			array(0, 14, 7, 11, 10, 4, 13, 1, 5, 8, 12, 6, 9, 3, 2, 15),
			array(13, 8, 10, 1, 3, 15, 4, 2, 11, 6, 7, 12, 0, 5, 14, 9)
		), array( //S3
			array(10, 0, 9, 14, 6, 3, 15, 5, 1, 13, 12, 7, 11, 4, 2, 8),
			array(13, 7, 0, 9, 3, 4, 6, 10, 2, 8, 5, 14, 12, 11, 15, 1),
			array(13, 6, 4, 9, 8, 15, 3, 0, 11, 1, 2, 12, 5, 10, 14, 7),
			array(1, 10, 13, 0, 6, 9, 8, 7, 4, 15, 14, 3, 11, 5, 2, 12)
		), array( //S4
			array(7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15),
			array(13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9),
			array(10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4),
			array(3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14)
		), array( //S5
			array(2, 12, 4, 1, 7, 10, 11, 6, 8, 5, 3, 15, 13, 0, 14, 9),
			array(14, 11, 2, 12, 4, 7, 13, 1, 5, 0, 15, 10, 3, 9, 8, 6),
			array(4, 2, 1, 11, 10, 13, 7, 8, 15, 9, 12, 5, 6, 3, 0, 14),
			array(11, 8, 12, 7, 1, 14, 2, 13, 6, 15, 0, 9, 10, 4, 5, 3)
		), array( //S6
			array(12, 1, 10, 15, 9, 2, 6, 8, 0, 13, 3, 4, 14, 7, 5, 11),
			array(10, 15, 4, 2, 7, 12, 9, 5, 6, 1, 13, 14, 0, 11, 3, 8),
			array(9, 14, 15, 5, 2, 8, 12, 3, 7, 0, 4, 10, 1, 13, 11, 6),
			array(4, 3, 2, 12, 9, 5, 15, 10, 11, 14, 1, 7, 6, 0, 8, 13)
		), array( //S7
			array(4, 11, 2, 14, 15, 0, 8, 13, 3, 12, 9, 7, 5, 10, 6, 1),
			array(13, 0, 11, 7, 4, 9, 1, 10, 14, 3, 5, 12, 2, 15, 8, 6),
			array(1, 4, 11, 13, 12, 3, 7, 14, 10, 15, 6, 8, 0, 5, 9, 2),
			array(6, 11, 13, 8, 1, 4, 10, 7, 9, 5, 0, 15, 14, 2, 3, 12)
		), array( //S8
			array(13, 2, 8, 4, 6, 15, 11, 1, 10, 9, 3, 14, 5, 0, 12, 7),
			array(1, 15, 13, 8, 10, 3, 7, 4, 12, 5, 6, 11, 0, 14, 9, 2),
			array(7, 11, 4, 1, 9, 12, 14, 2, 0, 6, 10, 13, 15, 3, 5, 8),
			array(2, 1, 14, 7, 4, 10, 8, 13, 15, 12, 9, 0, 3, 5, 6, 11)
		)
	);

	$des_sbox_permute = array(
		16, 7, 20, 21,
		29, 12, 28, 17,
		1, 15, 23, 26,
		5, 18, 31, 10,
		2, 8, 24, 14,
		32, 27, 3, 9,
		19, 13, 30, 6,
		22, 11, 4, 25
	);

	$des_final_permute = array(
		40, 8, 48, 16, 56, 24, 64, 32,
		39, 7, 47, 15, 55, 23, 63, 31,
		38, 6, 46, 14, 54, 22, 62, 30,
		37, 5, 45, 13, 53, 21, 61, 29,
		36, 4, 44, 12, 52, 20, 60, 28,
		35, 3, 43, 11, 51, 19, 59, 27,
		34, 2, 42, 10, 50, 18, 58, 26,
		33, 1, 41, 9, 49, 17, 57, 25
	);

	function cifs_des_permute($keybits, $permutation) {
		$pkeybits = array();
		for($i = 0; $i < sizeof($permutation); $i++) {
			$pkeybits[$i] = $keybits[$permutation[$i] - 1];
		}

		return $pkeybits;
	}

	function cifs_des_rotate($key, $shifts) {
		$out = array();
		for($i = 0; $i < sizeof($key); $i++) { $out[$i] = $key[($i+$shifts)%sizeof($key)]; }
		return $out;
	}

	function cifs_des_str2bits($str) {
		$bits = array();
		for($i = 0; $i < strlen($str); $i++) {
			$byte = ord(substr($str, $i, 1));
			for($j = 0; $j < 8; $j++) {
				$bits[$i*8+$j] = ($byte >> (7 - $j)) & 1;
			}
		}
		return $bits;
	}

	function cifs_des_desfunc($r, $k) {
		global $des_permute_e, $des_sbox, $des_sbox_permute;

		$r_e = cifs_des_permute($r, $des_permute_e);
		$r_e_plus_k = array();
		for($i = 0; $i < sizeof($r_e); $i++) { $r_e_plus_k[$i] = ($r_e[$i] + $k[$i]) % 2; }

		$output = array();
		for($box = 0; $box < 8; $box++) {
			$i = ($r_e_plus_k[$box*6] << 1) | ($r_e_plus_k[$box*6+5]);
			$j = ($r_e_plus_k[$box*6+1] << 3) | ($r_e_plus_k[$box*6+2] << 2) | ($r_e_plus_k[$box*6+3] << 1) | ($r_e_plus_k[$box*6+4]);
			for($sbox_bit = 0; $sbox_bit < 4; $sbox_bit++) {
				$sbox_output_bit = ($des_sbox[$box][$i][$j] & (1<<(3-$sbox_bit))) ? 1 : 0;
				$output[$box*4+$sbox_bit] = $sbox_output_bit;
			}
		}

		$result = cifs_des_permute($output, $des_sbox_permute);

		return $result;
	}

	function cifs_des($message, $key) {
		global $des_shifts, $des_permute1, $des_permute2, $des_initial_permute, $des_final_permute;

		$keybits = cifs_des_str2bits($key);
		$pkey = cifs_des_permute($keybits, $des_permute1);

		$c = array(); $c[0] = array();
		$d = array(); $d[0] = array();
		$k = array(); $k[0] = array();
		for($i = 0; $i < 28; $i++) {
			$c[0][$i] = $pkey[$i];
			$d[0][$i] = $pkey[$i+28];
		}

		for($i = 1; $i < sizeof($des_shifts); $i++) {
			$c[$i] = cifs_des_rotate($c[$i-1], $des_shifts[$i]);
			$d[$i] = cifs_des_rotate($d[$i-1], $des_shifts[$i]);

			$inkey = $c[$i];
			for($j = 0; $j < sizeof($d[$i]); $j++) { $inkey[sizeof($c[$i])+$j] = $d[$i][$j]; }

			$k[$i] = cifs_des_permute($inkey, $des_permute2);
		}


		$msgbits = cifs_des_str2bits($message);
		$pmessage = cifs_des_permute($msgbits, $des_initial_permute);

		$l = array(); $r = array(); $l[0] = array(); $r[0] = array();
		for($i = 0; $i < 32; $i++) {
			$l[0][$i] = $pmessage[$i];
			$r[0][$i] = $pmessage[32+$i];
		}


		for($i = 1; $i <= 16; $i++) {
			$l[$i] = $r[$i - 1];
			$f = cifs_des_desfunc($r[$i-1], $k[$i]);
			for($j = 0; $j < sizeof($l[$i-1]); $j++) {
				$r[$i][$j] = ($l[$i-1][$j] + $f[$j]) % 2;
			}
		}

		$lastblock = array();
		for($i = 0; $i < 32; $i++) {
			$lastblock[$i] = $r[16][$i];
			$lastblock[$i+32] = $l[16][$i];
		}

		$cipherbits = cifs_des_permute($lastblock, $des_final_permute);
		$ciphertext = "";
		for($i = 0; $i < sizeof($cipherbits)/8; $i++) {
			$cipherbyte = 0;
			for($j = 0; $j < 8; $j++) {
				$cipherbyte |= ($cipherbits[$i*8+$j] << (7 - $j));
			}
			$ciphertext .= chr($cipherbyte);
		}

		return $ciphertext;
	}
?>
