CREATE TABLE IF NOT EXISTS `player_crafting_benches` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `bench_type` varchar(50) NOT NULL,
  `coords_x` float NOT NULL,
  `coords_y` float NOT NULL,
  `coords_z` float NOT NULL,
  `heading` float NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
