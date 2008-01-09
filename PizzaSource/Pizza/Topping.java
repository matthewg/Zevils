package Pizza;

/**
 * Written by Matthew Sachs, 2006-03-08, for a lecture on unit testing
 * in Brandeis University's COSI 22a.  Source and lecture notes are released
 * into the public domain.
 *
 * @author Matthew Sachs 
 * @version 1.0
 * @see <a href="http://www.zevils.com/writings/unit-testing/">http://www.zevils.com/writings/unit-testing/</a>
 */
public class Topping {
	public static final int NOTYPE = 0;
	public static final int CHEESE = 1;
	public static final int MEAT = 2;
	public static final int VEGGIE = 3;

	private String name;
	private int type;

	public Topping(String name, int type) {
		this.name = name;
		this.type = type;
	}
	public String toString() { return name; }
	public String name() { return name; }
	public int type() { return type; }
	public boolean equals(Object o) {
		if(!(o instanceof Topping)) return false;
		Topping t = (Topping)o;
		if(type() != t.type()) return false;
		if((name() == null) != (t.name() == null)) return false;
		if(name() == null) return true;
		if(!name().equals(t.name())) return false;
		return true;
	}
}
