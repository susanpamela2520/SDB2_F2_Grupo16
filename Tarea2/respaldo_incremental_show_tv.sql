-- MySQL dump 10.13  Distrib 9.4.0, for Linux (x86_64)
--
-- Host: localhost    Database: based_tarea
-- ------------------------------------------------------
-- Server version	9.4.0

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `show_tv`
--

DROP TABLE IF EXISTS `show_tv`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `show_tv` (
  `id_show` int NOT NULL AUTO_INCREMENT,
  `show_id` varchar(10) NOT NULL,
  `title` varchar(255) NOT NULL,
  `date_added` date DEFAULT NULL,
  `release_year` int DEFAULT NULL,
  `duration` varchar(50) DEFAULT NULL,
  `description` text,
  `id_category` int DEFAULT NULL,
  `id_country` int DEFAULT NULL,
  `id_director` int DEFAULT NULL,
  `id_show_type` int NOT NULL,
  `id_rating` int DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id_show`),
  UNIQUE KEY `show_id` (`show_id`),
  KEY `id_category` (`id_category`),
  KEY `id_country` (`id_country`),
  KEY `id_director` (`id_director`),
  KEY `id_show_type` (`id_show_type`),
  KEY `id_rating` (`id_rating`),
  KEY `idx_show_id` (`show_id`),
  KEY `idx_title` (`title`),
  KEY `idx_release_year` (`release_year`),
  CONSTRAINT `show_tv_ibfk_1` FOREIGN KEY (`id_category`) REFERENCES `category` (`id_category`) ON DELETE SET NULL,
  CONSTRAINT `show_tv_ibfk_2` FOREIGN KEY (`id_country`) REFERENCES `country` (`id_country`) ON DELETE SET NULL,
  CONSTRAINT `show_tv_ibfk_3` FOREIGN KEY (`id_director`) REFERENCES `director` (`id_director`) ON DELETE SET NULL,
  CONSTRAINT `show_tv_ibfk_4` FOREIGN KEY (`id_show_type`) REFERENCES `show_type` (`id_show_type`) ON DELETE RESTRICT,
  CONSTRAINT `show_tv_ibfk_5` FOREIGN KEY (`id_rating`) REFERENCES `show_rating` (`id_rating`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=8808 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `show_tv`
--
-- WHERE:  updated_at >= '2025-08-13 14:37:26'

LOCK TABLES `show_tv` WRITE;
/*!40000 ALTER TABLE `show_tv` DISABLE KEYS */;
INSERT INTO `show_tv` VALUES (3,'s3','El show de Naomi','2021-09-24',2021,'1 Season','To protect his family from a powerful drug lord, skilled thief Mehdi and his expert team of robbers are pulled into a violent and deadly turf war.',6,NULL,NULL,2,11,'2025-07-30 05:34:41','2025-08-13 21:28:36');
/*!40000 ALTER TABLE `show_tv` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-08-13 21:37:06
