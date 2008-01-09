package Pizza;
import Pizza.Topping;

/**
 * A topping constraint is a restriction/preference about what sort of
 * toppings the pizza must/should have.
 *
 * Written by Matthew Sachs, 2006-03-08, for a lecture on unit testing
 * in Brandeis University's COSI 22a.  Source and lecture notes are released
 * into the public domain.
 *
 * @author Matthew Sachs 
 * @version 1.0
 * @see <a href="http://www.zevils.com/writings/unit-testing/">http://www.zevils.com/writings/unit-testing/</a>
 */
public class ToppingConstraint {
	private boolean isNegative;
	private boolean isMandatory;
	private Topping topping;

	public ToppingConstraint(boolean isNegative, boolean isMandatory, Topping topping) {
		this.isNegative = isNegative;
		this.isMandatory = isMandatory;
		this.topping = topping;
	}
	public boolean isNegative() { return isNegative; }
	public boolean isMandatory() { return isMandatory; }
	public Topping topping() { return topping; }
	public boolean matches(Topping t) {
		if((topping.type() != Topping.NOTYPE) && (t.type() != topping.type()))
			return false;
		if((topping.name() != null) && !topping.name().equals(t.name()))
			return false;
		return true;
	}
	public boolean equals(Object o) {
		if(!(o instanceof ToppingConstraint)) return false;
		ToppingConstraint c = (ToppingConstraint)o;
		return (
			(c.isMandatory() == isMandatory()) &&
			(c.isNegative() == isNegative()) &&
			(c.topping().equals(topping()))
		);
	}
}
