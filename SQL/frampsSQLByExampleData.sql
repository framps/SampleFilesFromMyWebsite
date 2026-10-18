-- phpMyAdmin SQL Dump
-- version 3.4.7
-- http://www.phpmyadmin.net
--
-- Host: localhost
-- Generation Time: Nov 13, 2011 at 06:15 PM
-- Server version: 5.1.53
-- PHP Version: 5.3.5

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;

--
-- Database: `frampsSQLByExample`
--

CREATE DATABASE frampsSQLByExample;

USE frampsSQLByExample;

-- --------------------------------------------------------

--
-- Table structure for table `Address`
--

CREATE TABLE IF NOT EXISTS `Address` (
  `id` int(11) NOT NULL,
  `City_Id` int(11) NOT NULL,
  `Street` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `No` varchar(45) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `Address`
--

INSERT INTO `Address` (`id`, `City_Id`, `Street`, `No`) VALUES
(1, 1, 'Bondstreet', '13'),
(2, 2, 'PlaceDeLetoile', '45'),
(3, 3, 'BarneysStreet', '5'),
(4, 4, 'ShiningStreet', '10');

-- --------------------------------------------------------

--
-- Table structure for table `City`
--

CREATE TABLE IF NOT EXISTS `City` (
  `id` int(11) NOT NULL,
  `Name` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `ZIP` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `City`
--

INSERT INTO `City` (`id`, `Name`, `ZIP`) VALUES
(1, 'Rochester', 87656),
(2, 'Paris', 1234),
(3, 'Wien', 52637),
(4, 'Berlin', 12987),
(5, 'New York', 65432);

-- --------------------------------------------------------

--
-- Stand-in structure for view `fatherOnly`
--
CREATE TABLE IF NOT EXISTS `fatherOnly` (
`LastName` varchar(45)
,`FirstName` varchar(45)
);
-- --------------------------------------------------------

--
-- Table structure for table `Friend`
--

CREATE TABLE IF NOT EXISTS `Friend` (
  `id` int(11) NOT NULL,
  `from_Id` int(11) NOT NULL,
  `to_Id` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `Friend`
--

INSERT INTO `Friend` (`id`, `from_Id`, `to_Id`) VALUES
(1, 3, 9),
(2, 9, 3),
(3, 4, 10),
(4, 10, 4),
(5, 3, 9),
(6, 9, 3);

-- --------------------------------------------------------

--
-- Table structure for table `Message`
--

CREATE TABLE IF NOT EXISTS `Message` (
  `id` int(11) NOT NULL,
  `from_Id` int(11) NOT NULL,
  `to_ID` int(11) NOT NULL,
  `message` varchar(45) COLLATE utf8_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `Message`
--

INSERT INTO `Message` (`id`, `from_Id`, `to_ID`, `message`) VALUES
(1, 1, 2, 'Nice to meet you'),
(2, 2, 1, 'I also enjoy to meet you'),
(3, 3, 1, 'My system crashed. Can you help me?'),
(4, 3, 2, 'I''m hungry'),
(5, 2, 3, 'Just visit MC''Donalds'),
(6, 1, 3, 'Restart your system'),
(7, 3, 1, 'Could you help me with GMAT?'),
(8, 3, 1, 'Don''t forget me and buy a big mac for me');

-- --------------------------------------------------------

--
-- Stand-in structure for view `motherOnly`
--
CREATE TABLE IF NOT EXISTS `motherOnly` (
`LastName` varchar(45)
,`FirstName` varchar(45)
);
-- --------------------------------------------------------

--
-- Table structure for table `Person`
--

CREATE TABLE IF NOT EXISTS `Person` (
  `id` int(11) NOT NULL,
  `LastName` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `FirstName` varchar(45) COLLATE utf8_unicode_ci NOT NULL,
  `Father_Id` int(11) DEFAULT NULL,
  `Mother_Id` int(11) DEFAULT NULL,
  `Address_Id` int(11) DEFAULT NULL,
  `Gender` char(1) COLLATE utf8_unicode_ci DEFAULT NULL,
  `Height` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `Person`
--

INSERT INTO `Person` (`id`, `LastName`, `FirstName`, `Father_Id`, `Mother_Id`, `Address_Id`, `Gender`, `Height`) VALUES
(1, 'Turner', 'Peter', 6, 5, 1, 'M', 180),
(2, 'Turner', 'Angie', NULL, 8, 1, 'F', 160),
(3, 'Turner', 'Marvin', 1, 2, 2, 'M', 185),
(4, 'Turner', 'Roxanne', 1, 2, 1, 'F', 155),
(5, 'Turner', 'Wendy', 8, NULL, 3, 'F', 167),
(6, 'Turner', 'Richard', NULL, NULL, 3, 'M', 162),
(8, 'Wilson', 'Hilary', NULL, NULL, 4, 'F', 169),
(7, 'Wilson', 'Woodrow', NULL, NULL, 4, 'M', 174),
(10, 'Chen', 'Walter', NULL, NULL, NULL, 'M', 156),
(9, 'Robinson', 'Rick', NULL, NULL, NULL, 'M', 189);

-- --------------------------------------------------------

--
-- Table structure for table `Sibling`
--

CREATE TABLE IF NOT EXISTS `Sibling` (
  `id` int(11) NOT NULL,
  `from_Id` int(11) NOT NULL,
  `to_Id` int(11) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;

--
-- Dumping data for table `Sibling`
--

INSERT INTO `Sibling` (`id`, `from_Id`, `to_Id`) VALUES
(1, 3, 4),
(2, 4, 3);

-- --------------------------------------------------------

--
-- Structure for view `fatherOnly`
--
DROP TABLE IF EXISTS `fatherOnly`;

CREATE ALGORITHM=UNDEFINED DEFINER=`peter`@`localhost` SQL SECURITY DEFINER VIEW `fatherOnly` AS select `Person`.`LastName` AS `LastName`,`Person`.`FirstName` AS `FirstName` from `Person` where (isnull(`Person`.`Father_Id`) and (`Person`.`Mother_Id` is not null));

-- --------------------------------------------------------

--
-- Structure for view `motherOnly`
--
DROP TABLE IF EXISTS `motherOnly`;

CREATE ALGORITHM=UNDEFINED DEFINER=`peter`@`localhost` SQL SECURITY DEFINER VIEW `motherOnly` AS select `Person`.`LastName` AS `LastName`,`Person`.`FirstName` AS `FirstName` from `Person` where ((`Person`.`Father_Id` is not null) and isnull(`Person`.`Mother_Id`));

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
